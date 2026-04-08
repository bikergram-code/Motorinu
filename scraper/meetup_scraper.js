#!/usr/bin/env node
/**
 * Bikergram Meetup Scraper
 *
 * Scrapes motorcycle meetup events from German biker websites
 * and inserts them into the Supabase `meetups` table.
 *
 * Sources:
 *   1. motorradtreffentermine.de
 *   2. tourenfahrer.de (TODO)
 *   3. 1000ps.de (TODO)
 *
 * Usage:
 *   node meetup_scraper.js
 *
 * Cronjob (daily at 6am):
 *   0 6 * * * cd /opt/bikergram && node meetup_scraper.js >> /var/log/meetup_scraper.log 2>&1
 */

const SUPABASE_URL = 'https://trmwbkpfafigraveneva.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || '';

// ─── HTML Entity Decoder ────────────────────────────────────────────────────

function decodeEntities(s) {
  return s
    .replace(/&uuml;/g, 'ü').replace(/&Uuml;/g, 'Ü')
    .replace(/&ouml;/g, 'ö').replace(/&Ouml;/g, 'Ö')
    .replace(/&auml;/g, 'ä').replace(/&Auml;/g, 'Ä')
    .replace(/&szlig;/g, 'ß')
    .replace(/&eacute;/g, 'é')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#\d+;/g, '')
    .replace(/<[^>]+>/g, '')  // strip HTML tags
    .replace(/\s+/g, ' ')
    .trim();
}

// ─── PLZ → approximate coordinates (German postal codes) ────────────────────

function plzToCoords(plz) {
  if (!plz || plz.length < 4) return null;
  const code = parseInt(plz.replace(/[^0-9]/g, ''));
  if (isNaN(code) || code < 1000 || code > 99999) return null;
  const region = Math.floor(code / 10000);
  const sub = code % 10000;
  switch (region) {
    case 0: return { lat: 51.05 + sub * 0.00005, lng: 13.74 + (code % 1000) * 0.0003 };
    case 1: return { lat: 52.52 + sub * 0.00004, lng: 13.40 + (code % 1000) * 0.0002 };
    case 2: return { lat: 53.55 + sub * 0.00003, lng: 9.99 + (code % 1000) * 0.0003 };
    case 3: return { lat: 52.37 + sub * 0.00004, lng: 9.74 + (code % 1000) * 0.0002 };
    case 4: return { lat: 51.48 + sub * 0.00003, lng: 7.45 + (code % 1000) * 0.0002 };
    case 5: return { lat: 50.94 + sub * 0.00003, lng: 6.96 + (code % 1000) * 0.0003 };
    case 6: return { lat: 50.11 + sub * 0.00004, lng: 8.68 + (code % 1000) * 0.0002 };
    case 7: return { lat: 48.78 + sub * 0.00004, lng: 9.18 + (code % 1000) * 0.0002 };
    case 8: return { lat: 48.14 + sub * 0.00004, lng: 11.58 + (code % 1000) * 0.0002 };
    case 9: return { lat: 49.45 + sub * 0.00004, lng: 11.08 + (code % 1000) * 0.0002 };
    default: return { lat: 51.16, lng: 10.45 };
  }
}

// ─── Date Parser ────────────────────────────────────────────────────────────

function parseGermanDate(raw) {
  const cleaned = decodeEntities(raw).replace(/\s/g, '');
  // Match first date in formats like "27.3.2026" or "27.3.-29.3.2026"
  const m = cleaned.match(/(\d{1,2})\.(\d{1,2})\.?(\d{4})?/);
  if (!m) return null;
  const day = parseInt(m[1]);
  const month = parseInt(m[2]);
  const year = m[3] ? parseInt(m[3]) : new Date().getFullYear();
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}T10:00:00+01:00`;
}

// ─── Extract URL from HTML ──────────────────────────────────────────────────

function extractUrl(html) {
  const m = html.match(/href='(https?:\/\/[^']+)'/i) || html.match(/href="(https?:\/\/[^"]+)"/i);
  return m ? m[1] : null;
}

// ─── Source 1: motorradtreffentermine.de ─────────────────────────────────────

async function scrapeMotorradtreffentermine() {
  console.log('[Scraper] Fetching motorradtreffentermine.de ...');

  const resp = await fetch('http://www.motorradtreffentermine.de/termine/termine_schraeglagenjunkies.php', {
    headers: { 'User-Agent': 'Mozilla/5.0 (compatible; BikergamBot/1.0)' }
  });

  if (!resp.ok) {
    console.error(`[Scraper] HTTP ${resp.status}`);
    return [];
  }

  const html = await resp.text();
  console.log(`[Scraper] Got ${html.length} bytes`);

  // Parse HTML table rows: Datum | Veranstalter | Veranstaltung | Ort | PLZ | Infos
  const rowRegex = /<tr>\s*<td[^>]*><b>([\s\S]*?)<\/b><\/td>\s*<td[^>]*><b>([\s\S]*?)<\/b><\/td>\s*<td[^>]*><b>([\s\S]*?)<\/b><\/td>\s*<td[^>]*><b>([\s\S]*?)<\/b><\/td>\s*<td[^>]*><b>([\s\S]*?)<\/b><\/td>\s*<td[^>]*><b>([\s\S]*?)<\/b><\/td>/g;

  const meetups = [];
  let match;

  while ((match = rowRegex.exec(html))) {
    const dateRaw = match[1];
    const organizer = decodeEntities(match[2]);
    const eventName = decodeEntities(match[3]);
    const location = decodeEntities(match[4]);
    const plz = match[5].trim().replace(/[^0-9]/g, '');
    const infoHtml = match[6];

    const startsAt = parseGermanDate(dateRaw);
    if (!startsAt) continue;

    // Skip past events
    if (new Date(startsAt) < new Date()) continue;

    const url = extractUrl(infoHtml);
    const title = `${eventName} — ${organizer}`;
    const locationText = plz ? `${location} (${plz})` : location;

    const coords = plzToCoords(plz);
    meetups.push({
      title: title.substring(0, 200),
      location_text: locationText.substring(0, 200),
      latitude: coords?.lat || null,
      longitude: coords?.lng || null,
      starts_at: startsAt,
      source_url: url || 'http://www.motorradtreffentermine.de',
      source_name: 'motorradtreffentermine.de',
      community: 'bikergram',
      region: plz ? `PLZ ${plz.substring(0, 2)}xxx` : null,
    });
  }

  console.log(`[Scraper] Parsed ${meetups.length} upcoming meetups from motorradtreffentermine.de`);
  return meetups;
}

// ─── Source 2: tourenfahrer.de ───────────────────────────────────────────────

async function scrapeTourenfahrer() {
  console.log('[Scraper] Fetching tourenfahrer.de ...');

  const resp = await fetch('https://www.tourenfahrer.de/events-szene/motorrad-termine', {
    headers: { 'User-Agent': 'Mozilla/5.0 (compatible; BikergamBot/1.0)' }
  });

  if (!resp.ok) {
    console.error(`[Scraper] tourenfahrer.de HTTP ${resp.status}`);
    return [];
  }

  const html = await resp.text();
  console.log(`[Scraper] Got ${html.length} bytes from tourenfahrer.de`);

  // Pattern: date → title (with optional link) → location
  const blockRegex = /(\d{2}\.\d{2}\.\d{4})\s*<\/div>[\s\S]*?event-title[^>]*>\s*(?:<a[^>]*href="([^"]*)"[^>]*>)?\s*([\s\S]*?)(?:<\/a>)?\s*<\/div>[\s\S]*?event-location[^>]*>\s*([\s\S]*?)\s*<\/div>/g;

  const meetups = [];
  let match;

  while ((match = blockRegex.exec(html))) {
    const dateStr = match[1].trim(); // DD.MM.YYYY
    const detailPath = (match[2] || '').trim();
    const title = decodeEntities(match[3]);
    const location = decodeEntities(match[4]);

    const parts = dateStr.split('.');
    if (parts.length < 3) continue;
    const ts = `${parts[2]}-${parts[1]}-${parts[0]}T10:00:00+01:00`;

    if (new Date(ts) < new Date()) continue;

    const sourceUrl = detailPath.startsWith('http')
      ? detailPath
      : `https://www.tourenfahrer.de${detailPath}`;

    meetups.push({
      title: title.substring(0, 200),
      location_text: location.substring(0, 200) || null,
      starts_at: ts,
      source_url: sourceUrl,
      source_name: 'tourenfahrer.de',
      community: 'bikergram',
    });
  }

  console.log(`[Scraper] Parsed ${meetups.length} upcoming meetups from tourenfahrer.de`);
  return meetups;
}

// ─── Source 3: 1000ps.de ────────────────────────────────────────────────────

async function scrape1000ps() {
  console.log('[Scraper] Fetching 1000ps.de ...');

  // Scrape multiple regions
  const regions = [
    { url: 'https://www.1000ps.de/motorrad-terminkalender-landregion-deutschland-nordrhein-westfalen-2-24', name: 'NRW' },
    { url: 'https://www.1000ps.de/motorrad-terminkalender-landregion-deutschland-bayern-2-7', name: 'Bayern' },
    { url: 'https://www.1000ps.de/motorrad-terminkalender-landregion-deutschland-baden-wuerttemberg-2-6', name: 'BaWü' },
    { url: 'https://www.1000ps.de/motorrad-terminkalender-landregion-deutschland-niedersachsen-2-18', name: 'Niedersachsen' },
    { url: 'https://www.1000ps.de/motorrad-terminkalender-landregion-deutschland-hessen-2-13', name: 'Hessen' },
    { url: 'https://www.1000ps.de/motorrad-terminkalender-landregion-deutschland-rheinland-pfalz-2-21', name: 'RLP' },
    { url: 'https://www.1000ps.de/motorrad-terminkalender-landregion-deutschland-saarland-2-22', name: 'Saarland' },
  ];

  const allMeetups = [];

  for (const region of regions) {
    try {
      const resp = await fetch(region.url, {
        headers: { 'User-Agent': 'Mozilla/5.0 (compatible; BikergamBot/1.0)' }
      });
      if (!resp.ok) continue;

      const html = await resp.text();

      // Pattern: card with link, title in alt attribute
      const cardRegex = /<div[^>]*id="(\d+)"[^>]*>\s*<div class="card[^"]*">\s*<a href="([^"]*)"[^>]*title="([^"]*)"[\s\S]*?<\/div>\s*<\/div>\s*<\/a>/g;

      let m;
      while ((m = cardRegex.exec(html))) {
        const detailUrl = `https://www.1000ps.de${m[2]}`;
        const title = decodeEntities(m[3])
          .replace(/^Motorrad (Veranstaltung|Termin)\s*/i, '');

        // Extract date from card body if available
        // Cards often have date in the body text — we'll use a secondary regex
        const cardBlock = html.substring(m.index, m.index + 2000);
        const dateMatch = cardBlock.match(/(\d{2})\.(\d{2})\.(\d{4})/);

        let ts;
        if (dateMatch) {
          ts = `${dateMatch[3]}-${dateMatch[2]}-${dateMatch[1]}T10:00:00+01:00`;
        } else {
          // Default to next month if no date found
          const next = new Date();
          next.setMonth(next.getMonth() + 1);
          ts = next.toISOString().split('T')[0] + 'T10:00:00+01:00';
        }

        if (new Date(ts) < new Date()) continue;

        // Avoid duplicates by title
        if (allMeetups.some(m => m.title === title.substring(0, 200))) continue;

        allMeetups.push({
          title: title.substring(0, 200),
          location_text: region.name,
          starts_at: ts,
          source_url: detailUrl,
          source_name: '1000ps.de',
          community: 'bikergram',
          region: region.name,
        });
      }
    } catch (e) {
      console.error(`[Scraper] 1000ps.de ${region.name} failed: ${e.message}`);
    }
  }

  console.log(`[Scraper] Parsed ${allMeetups.length} meetups from 1000ps.de`);
  return allMeetups;
}

// ─── Source 4: nuerburgring.de (Auto/Motorsport) ────────────────────────────

async function scrapeNuerburgring() {
  console.log('[Scraper] Fetching nuerburgring.de ...');

  const resp = await fetch('https://nuerburgring.de/events', {
    headers: { 'User-Agent': 'Mozilla/5.0 (compatible; BikergamBot/1.0)' }
  });

  if (!resp.ok) {
    console.error(`[Scraper] nuerburgring.de HTTP ${resp.status}`);
    return [];
  }

  const html = await resp.text();
  console.log(`[Scraper] Got ${html.length} bytes from nuerburgring.de`);

  // Pattern: date-day + date-month + title + link
  const re = /events-block__date-day">([\s\S]*?)<\/span>\s*<span class="events-block__date-month">([\s\S]*?)<\/span>[\s\S]*?events-item__title">\s*<a[^>]*href="([^"]*)"[^>]*>\s*([\s\S]*?)\s*<\/a>[\s\S]*?events-item__text">([\s\S]*?)<\/div>/g;

  const months = { Jan: 1, Feb: 2, Mar: 3, Apr: 4, May: 5, Jun: 6, Jul: 7, Aug: 8, Sep: 9, Oct: 10, Nov: 11, Dec: 12,
                   Mär: 3, Mai: 5, Okt: 10, Dez: 12 };
  const meetups = [];
  let match;

  while ((match = re.exec(html))) {
    const day = parseInt(match[1].trim());
    const monStr = match[2].trim();
    const mon = months[monStr] || months[monStr.substring(0, 3)];
    if (!mon || !day) continue;

    const year = new Date().getFullYear();
    const ts = `${year}-${String(mon).padStart(2, '0')}-${String(day).padStart(2, '0')}T10:00:00+01:00`;
    if (new Date(ts) < new Date()) continue;

    const detailPath = match[3].trim();
    const title = decodeEntities(match[4]);
    const desc = decodeEntities(match[5]).substring(0, 300);
    const sourceUrl = detailPath.startsWith('http') ? detailPath : `https://nuerburgring.de${detailPath}`;

    meetups.push({
      title: title.substring(0, 200),
      description: desc || null,
      location_text: 'Nürburgring',
      latitude: 50.332,
      longitude: 6.941,
      starts_at: ts,
      source_url: sourceUrl,
      source_name: 'nuerburgring.de',
      community: 'motorgram', // Auto/Motorsport
      region: 'Rheinland-Pfalz',
    });
  }

  console.log(`[Scraper] Parsed ${meetups.length} upcoming events from nuerburgring.de`);
  return meetups;
}

// ─── Source 5: motorsportmarkt.de (Auto/Motorsport) ─────────────────────────

async function scrapeMotorsportmarkt() {
  console.log('[Scraper] Fetching motorsportmarkt.de ...');

  const resp = await fetch('https://www.motorsportmarkt.de/veranstaltungen/', {
    headers: { 'User-Agent': 'Mozilla/5.0 (compatible; BikergamBot/1.0)' }
  });

  if (!resp.ok) {
    console.error(`[Scraper] motorsportmarkt.de HTTP ${resp.status}`);
    return [];
  }

  const html = await resp.text();
  console.log(`[Scraper] Got ${html.length} bytes from motorsportmarkt.de`);

  // Pattern: product--date + product--title link
  const re = /product--date">\s*([\d.]+)\s*<\/span>[\s\S]*?product--title"[^>]*href="([^"]*)"[^>]*>\s*([\s\S]*?)\s*<\/a>[\s\S]*?product--description">\s*([\s\S]*?)\s*<\/div>[\s\S]*?product--location">([\s\S]*?)<\/span>/g;

  const meetups = [];
  let match;

  while ((match = re.exec(html))) {
    const dateStr = match[1].trim(); // DD.MM.YYYY
    const parts = dateStr.split('.');
    if (parts.length < 3) continue;
    const ts = `${parts[2]}-${parts[1]}-${parts[0]}T10:00:00+01:00`;
    if (new Date(ts) < new Date()) continue;

    const sourceUrl = match[2].trim();
    const title = decodeEntities(match[3]);
    const desc = decodeEntities(match[4]).substring(0, 300);
    const location = decodeEntities(match[5]);

    meetups.push({
      title: title.substring(0, 200),
      description: desc || null,
      location_text: location.substring(0, 200) || null,
      starts_at: ts,
      source_url: sourceUrl,
      source_name: 'motorsportmarkt.de',
      community: 'motorgram',
    });
  }

  console.log(`[Scraper] Parsed ${meetups.length} events from motorsportmarkt.de`);
  return meetups;
}

// ─── Supabase Upsert ────────────────────────────────────────────────────────

async function upsertMeetups(meetups) {
  if (!SUPABASE_SERVICE_KEY) {
    console.error('[Scraper] SUPABASE_SERVICE_KEY not set! Set it as environment variable.');
    console.log('[Scraper] Printing SQL instead:\n');
    printSQL(meetups);
    return;
  }

  console.log(`[Scraper] Upserting ${meetups.length} meetups to Supabase ...`);

  // Delete ALL scraped meetups (fresh import every time)
  for (const src of ['motorradtreffentermine.de', 'tourenfahrer.de', '1000ps.de', 'nuerburgring.de', 'motorsportmarkt.de']) {
    const deleteResp = await fetch(`${SUPABASE_URL}/rest/v1/meetups?source_name=eq.${src}`, {
      method: 'DELETE',
      headers: {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
      },
    });
    console.log(`[Scraper] Deleted ${src}: ${deleteResp.status}`);
  }

  // Insert in batches of 50
  for (let i = 0; i < meetups.length; i += 50) {
    const batch = meetups.slice(i, i + 50);
    const resp = await fetch(`${SUPABASE_URL}/rest/v1/meetups`, {
      method: 'POST',
      headers: {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      },
      body: JSON.stringify(batch.map(m => ({
        title: m.title || '',
        description: m.description || null,
        image_url: m.image_url || null,
        location_text: m.location_text || null,
        latitude: m.latitude || null,
        longitude: m.longitude || null,
        starts_at: m.starts_at,
        ends_at: m.ends_at || null,
        source_url: m.source_url || null,
        source_name: m.source_name || null,
        community: m.community || 'bikergram',
        region: m.region || null,
        is_verified: m.is_verified || false,
      }))),
    });

    if (resp.ok) {
      console.log(`[Scraper] Inserted batch ${i / 50 + 1}: ${batch.length} meetups`);
    } else {
      const err = await resp.text();
      console.error(`[Scraper] Insert failed: ${resp.status} — ${err}`);
    }
  }

  console.log('[Scraper] Done!');
}

// ─── Fallback: Print SQL ────────────────────────────────────────────────────

function printSQL(meetups) {
  const esc = s => s.replace(/'/g, "''");
  console.log("DELETE FROM meetups WHERE source_name IN ('motorradtreffentermine.de', 'tourenfahrer.de', '1000ps.de', 'nuerburgring.de', 'motorsportmarkt.de');");
  console.log();
  console.log('INSERT INTO meetups (title, location_text, starts_at, source_url, source_name, community, region) VALUES');
  const vals = meetups.map(m =>
    `('${esc(m.title)}', '${esc(m.location_text)}', '${m.starts_at}', ${m.source_url ? "'" + esc(m.source_url) + "'" : 'NULL'}, '${m.source_name}', '${m.community}', ${m.region ? "'" + esc(m.region) + "'" : 'NULL'})`
  );
  console.log(vals.join(',\n') + ';');
}

// ─── Main ───────────────────────────────────────────────────────────────────

async function main() {
  console.log(`[Scraper] Bikergram Meetup Scraper — ${new Date().toISOString()}`);
  console.log('─'.repeat(60));

  const allMeetups = [];

  // Source 1
  try {
    const m1 = await scrapeMotorradtreffentermine();
    allMeetups.push(...m1);
  } catch (e) {
    console.error('[Scraper] motorradtreffentermine.de failed:', e.message);
  }

  // Source 2
  try {
    const m2 = await scrapeTourenfahrer();
    allMeetups.push(...m2);
  } catch (e) {
    console.error('[Scraper] tourenfahrer.de failed:', e.message);
  }

  // Source 3
  try {
    const m3 = await scrape1000ps();
    allMeetups.push(...m3);
  } catch (e) {
    console.error('[Scraper] 1000ps.de failed:', e.message);
  }

  // Source 4 — Auto/Motorsport
  try {
    const m4 = await scrapeNuerburgring();
    allMeetups.push(...m4);
  } catch (e) {
    console.error('[Scraper] nuerburgring.de failed:', e.message);
  }

  // Source 5 — Auto/Motorsport
  try {
    const m5 = await scrapeMotorsportmarkt();
    allMeetups.push(...m5);
  } catch (e) {
    console.error('[Scraper] motorsportmarkt.de failed:', e.message);
  }

  console.log(`\n[Scraper] Total: ${allMeetups.length} meetups from all sources`);

  if (allMeetups.length > 0) {
    await upsertMeetups(allMeetups);
  }
}

main().catch(e => {
  console.error('[Scraper] Fatal:', e);
  process.exit(1);
});
