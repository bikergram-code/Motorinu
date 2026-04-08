/// Zentrale Fahrzeug-Marken & Modelle Datenbank.
/// Wird von Marktplatz UND Garage genutzt.
class VehicleBrands {
  VehicleBrands._();

  // ══════════════════════════════════════════════
  //  MOTORRAD-MARKEN & MODELLE
  // ══════════════════════════════════════════════

  static const motorcycleBrands = <String, List<String>>{
    'Aprilia': [
      'RS 660', 'Tuono 660', 'RSV4', 'RSV4 Factory', 'Tuono V4',
      'RS 125', 'SX 125', 'RX 125', 'SR GT 125', 'SR GT 200',
      'Shiver 900', 'Dorsoduro 900',
    ],
    'Benelli': [
      'TRK 502', 'TRK 502 X', 'Leoncino 500', 'Leoncino 500 Trail',
      '752S', 'TNT 125', 'TRK 251', 'BN 125', '502C',
    ],
    'BMW': [
      'S 1000 RR', 'S 1000 R', 'S 1000 XR', 'M 1000 RR', 'M 1000 R',
      'R 1300 GS', 'R 1300 GS Adventure', 'R 1250 GS', 'R 1250 GS Adventure',
      'R 1250 RT', 'R 1250 RS',
      'F 900 R', 'F 900 XR', 'F 900 GS', 'F 900 GS Adventure',
      'F 750 GS', 'F 800 GS',
      'G 310 R', 'G 310 GS',
      'R nineT', 'R nineT Pure', 'R nineT Scrambler', 'R nineT Urban G/S',
      'K 1600 GT', 'K 1600 GTL', 'K 1600 B', 'K 1600 Grand America',
      'R 18', 'R 18 Classic', 'R 18 Transcontinental', 'R 18 Roctane',
      'CE 04', 'CE 02',
    ],
    'Brixton': [
      'Cromwell 1200', 'Crossfire 500', 'Crossfire 500 XC',
      'Cromwell 250', 'Felsberg 250', 'Sunray 125',
    ],
    'Can-Am': [
      'Spyder F3', 'Spyder RT', 'Ryker 600', 'Ryker 900',
    ],
    'CFMoto': [
      '700CL-X Heritage', '700CL-X Sport', '700CL-X Adventure',
      '450SS', '450SR', '450NK', '300NK', '300SS',
      '650GT', '650MT', '650NK', '800MT', '800MT Explore',
    ],
    'Ducati': [
      'Panigale V4', 'Panigale V4 S', 'Panigale V4 SP2', 'Panigale V4 R',
      'Panigale V2',
      'Streetfighter V4', 'Streetfighter V4 S', 'Streetfighter V4 SP',
      'Streetfighter V2',
      'Monster', 'Monster SP', 'Monster +',
      'Multistrada V4', 'Multistrada V4 S', 'Multistrada V4 Rally', 'Multistrada V4 Pikes Peak',
      'Multistrada V2', 'Multistrada V2 S',
      'Scrambler Icon', 'Scrambler Full Throttle', 'Scrambler Nightshift', 'Scrambler Urban Motard',
      'Desert X', 'Desert X Rally', 'Desert X Discovery',
      'Diavel V4', 'XDiavel',
      'SuperSport 950', 'SuperSport 950 S',
      'Hypermotard 950', 'Hypermotard 950 SP', 'Hypermotard 950 RVE',
    ],
    'Fantic': [
      'Rally 500', 'Caballero 500', 'Caballero 700',
      'XEF 125', 'XMF 125',
    ],
    'Gas Gas': [
      'SM 700', 'ES 700',
      'MC 250F', 'MC 350F', 'MC 450F',
      'EC 250', 'EC 300', 'EC 350F',
    ],
    'Harley-Davidson': [
      'Sportster S', 'Nightster', 'Nightster Special',
      'Fat Boy', 'Fat Boy 114', 'Heritage Classic',
      'Road Glide', 'Road Glide Special', 'Road Glide Limited', 'Road Glide Ultra',
      'Street Glide', 'Street Glide Special', 'Street Glide ST',
      'Road King', 'Road King Special',
      'Electra Glide Ultra Limited',
      'Pan America 1250', 'Pan America 1250 Special',
      'Low Rider', 'Low Rider S', 'Low Rider ST', 'Low Rider El Diablo',
      'Breakout', 'Fat Bob', 'Softail Standard', 'Softail Slim',
      'Iron 883', 'Forty-Eight',
      'LiveWire One', 'LiveWire S2 Del Mar',
      'X 350', 'X 500',
    ],
    'Honda': [
      'CBR 1000RR-R Fireblade', 'CBR 1000RR-R SP',
      'CBR 650R', 'CBR 500R',
      'CB 1000R', 'CB 650R', 'CB 500F', 'CB 500X', 'CB 300R', 'CB 125R',
      'CRF 1100L Africa Twin', 'CRF 1100L Africa Twin Adventure Sports',
      'NC750X', 'NT1100',
      'CMX 500 Rebel', 'CMX 1100 Rebel',
      'XL750 Transalp',
      'CL500 Scrambler', 'CL250',
      'Monkey 125', 'Dax 125', 'MSX 125 Grom',
      'Forza 750', 'Forza 350', 'Forza 125',
      'PCX 125', 'ADV 350',
      'X-ADV 750',
      'Gold Wing', 'Gold Wing Tour',
      'CRF 300L', 'CRF 300 Rally',
      'SH 125', 'SH 350',
    ],
    'Husqvarna': [
      'Norden 901', 'Norden 901 Expedition',
      'Svartpilen 701', 'Svartpilen 401', 'Svartpilen 125',
      'Vitpilen 701', 'Vitpilen 401', 'Vitpilen 125',
      '701 Supermoto', '701 Enduro',
      'FC 250', 'FC 350', 'FC 450',
      'FE 250', 'FE 350', 'FE 450', 'FE 501',
      'TE 150i', 'TE 250i', 'TE 300i',
    ],
    'Indian': [
      'Scout', 'Scout Bobber', 'Scout Rogue',
      'Chief', 'Chief Bobber', 'Chief Dark Horse',
      'Super Chief', 'Super Chief Limited',
      'Challenger', 'Challenger Limited', 'Challenger Dark Horse',
      'Pursuit', 'Pursuit Limited', 'Pursuit Dark Horse',
      'FTR', 'FTR S', 'FTR R Carbon', 'FTR Rally',
      'Springfield', 'Springfield Dark Horse',
      'Roadmaster', 'Roadmaster Limited',
      'Chieftain', 'Chieftain Limited', 'Chieftain Dark Horse',
    ],
    'Kawasaki': [
      'Ninja ZX-10R', 'Ninja ZX-10RR', 'Ninja ZX-10R SE',
      'Ninja ZX-6R', 'Ninja ZX-4R', 'Ninja ZX-4RR',
      'Ninja 650', 'Ninja 400', 'Ninja 300', 'Ninja 125',
      'Ninja H2', 'Ninja H2 SX', 'Ninja H2 SX SE',
      'Z H2', 'Z H2 SE',
      'Z900', 'Z900 SE', 'Z900RS', 'Z900RS SE',
      'Z650', 'Z650RS',
      'Z400', 'Z125',
      'Versys 1000', 'Versys 1000 SE', 'Versys 650',
      'Vulcan S', 'Vulcan 900 Classic',
      'W800', 'W800 Cafe', 'W800 Street',
      'KLX 300', 'KLX 230', 'KLX 110',
      'KX 250', 'KX 450',
      'Eliminator 500',
    ],
    'KTM': [
      '1390 Super Duke R', '1290 Super Duke R', '1290 Super Duke R EVO',
      '1290 Super Duke GT',
      '1290 Super Adventure S', '1290 Super Adventure R',
      '890 Adventure', '890 Adventure R', '890 Adventure Rally',
      '890 Duke', '890 Duke R',
      '790 Duke', '790 Adventure',
      '690 SMC R', '690 Enduro R',
      '390 Duke', '390 Adventure',
      '125 Duke', '125 SX',
      'RC 390', 'RC 125',
      '300 EXC TPI', '250 EXC-F', '350 EXC-F', '450 EXC-F', '500 EXC-F',
      '250 SX-F', '350 SX-F', '450 SX-F',
      'Freeride E-XC',
    ],
    'Moto Guzzi': [
      'V7', 'V7 Stone', 'V7 Special',
      'V85 TT', 'V85 TT Travel',
      'V100 Mandello', 'V100 Mandello S',
      'Stelvio',
      'Griso 1200',
    ],
    'Moto Morini': [
      'X-Cape 650', 'X-Cape 650 Adventure',
      'Seiemmezzo STR', 'Seiemmezzo SCR',
      'Calibro 650',
    ],
    'MV Agusta': [
      'F3 675', 'F3 800', 'F3 800 RR',
      'Brutale 800', 'Brutale 800 RR', 'Brutale 1000 RR', 'Brutale 1000 RS',
      'Dragster 800', 'Dragster 800 RR', 'Dragster 800 RR SCS',
      'Turismo Veloce 800', 'Turismo Veloce 800 Lusso',
      'Superveloce 800', 'Superveloce 1000 Serie Oro',
      'Rush 1000',
      'Lucky Explorer 5.5', 'Lucky Explorer 9.5',
    ],
    'Norton': [
      'Commando 961', 'V4SV', 'V4CR',
    ],
    'Peugeot': [
      'Metropolis', 'Pulsion 125', 'Django 125', 'Speedfight 125',
      'Tweet 125', 'Kisbee 50',
    ],
    'Piaggio': [
      'Beverly 300', 'Beverly 400', 'Medley 125', 'Liberty 125',
      'MP3 300', 'MP3 530',
    ],
    'Royal Enfield': [
      'Meteor 350', 'Classic 350', 'Bullet 350',
      'Hunter 350',
      'Himalayan', 'Himalayan 450',
      'Continental GT 650', 'Interceptor 650',
      'Super Meteor 650',
      'Scram 411',
      'Shotgun 650',
    ],
    'Suzuki': [
      'GSX-R1000', 'GSX-R1000R',
      'GSX-R750', 'GSX-R600',
      'GSX-S1000', 'GSX-S1000GT', 'GSX-S1000F',
      'GSX-S750',
      'GSX-8S', 'GSX-8R',
      'Hayabusa',
      'SV650', 'SV650X',
      'V-Strom 1050', 'V-Strom 1050 DE', 'V-Strom 1050 XT',
      'V-Strom 800', 'V-Strom 800 DE',
      'V-Strom 650', 'V-Strom 650 XT',
      'V-Strom 250',
      'Katana',
      'DR-Z400S', 'DR-Z400SM',
      'Boulevard C50', 'Boulevard M109R',
      'Burgman 400', 'Burgman 200',
      'GSX-S125', 'GSX-R125',
    ],
    'SWM': [
      'Gran Milano 440', 'Silver Vase 440',
      'Superdual 600', 'RS 125 R',
    ],
    'Triumph': [
      'Speed Triple 1200', 'Speed Triple 1200 RS', 'Speed Triple 1200 RR',
      'Street Triple 765', 'Street Triple 765 R', 'Street Triple 765 RS', 'Street Triple 765 Moto2',
      'Tiger 900', 'Tiger 900 Rally', 'Tiger 900 Rally Pro', 'Tiger 900 GT', 'Tiger 900 GT Pro',
      'Tiger 1200', 'Tiger 1200 Rally', 'Tiger 1200 Rally Explorer', 'Tiger 1200 GT', 'Tiger 1200 GT Explorer',
      'Tiger Sport 660',
      'Trident 660',
      'Bonneville T120', 'Bonneville T100', 'Bonneville Bobber',
      'Thruxton RS',
      'Scrambler 900', 'Scrambler 1200 XC', 'Scrambler 1200 XE',
      'Street Scrambler',
      'Rocket 3 R', 'Rocket 3 GT',
      'Speed 400', 'Scrambler 400 X',
      'Speed Twin 900', 'Speed Twin 1200',
      'Daytona 660',
    ],
    'Vespa': [
      'GTS 300', 'GTS 125', 'GTV 300',
      'Primavera 125', 'Primavera 150',
      'Sprint 125', 'Sprint 150',
      'Elettrica',
      'LX 125', 'S 125',
    ],
    'Voge': [
      '500DS', '650DS', '900DS',
      '300R', '500R', '525R',
      '300AC',
    ],
    'Yamaha': [
      'YZF-R1', 'YZF-R1M',
      'YZF-R7', 'YZF-R6', 'YZF-R3', 'YZF-R125',
      'MT-10', 'MT-10 SP',
      'MT-09', 'MT-09 SP',
      'MT-07',
      'MT-03', 'MT-125',
      'Ténéré 700', 'Ténéré 700 Rally', 'Ténéré 700 World Raid', 'Ténéré 700 Explore',
      'Tracer 9', 'Tracer 9 GT', 'Tracer 9 GT+',
      'Tracer 7', 'Tracer 7 GT',
      'XSR 900', 'XSR 900 GP',
      'XSR 700',
      'XSR 125',
      'NIKEN', 'NIKEN GT',
      'FJR 1300',
      'XJ6',
      'TMAX 560', 'TMAX 560 Tech Max',
      'XMAX 300', 'XMAX 125',
      'NMAX 125', 'NMAX 155',
      'WR 250F', 'WR 450F',
      'YZ 250F', 'YZ 450F', 'YZ 250',
      'XV950 Bolt',
      'Star Venture',
    ],
    'Zontes': [
      '350-T', '350-D', '350-R', '350-GK',
      '310-T', '310-R', '310-V', '310-X',
      '125-G1', '125-U',
    ],
  };

  // ══════════════════════════════════════════════
  //  AUTO-MARKEN (Modelle als Freitext)
  // ══════════════════════════════════════════════

  static const carBrands = <String>[
    'Alfa Romeo',
    'Aston Martin',
    'Audi',
    'Bentley',
    'BMW',
    'Bugatti',
    'Cadillac',
    'Chevrolet',
    'Chrysler',
    'Citroën',
    'Cupra',
    'Dacia',
    'Dodge',
    'DS Automobiles',
    'Ferrari',
    'Fiat',
    'Ford',
    'Genesis',
    'Honda',
    'Hyundai',
    'Infiniti',
    'Isuzu',
    'Jaguar',
    'Jeep',
    'Kia',
    'Lamborghini',
    'Land Rover',
    'Lexus',
    'Lotus',
    'Maserati',
    'Mazda',
    'McLaren',
    'Mercedes-Benz',
    'Mini',
    'Mitsubishi',
    'Nissan',
    'Opel',
    'Peugeot',
    'Polestar',
    'Porsche',
    'Renault',
    'Rolls-Royce',
    'Seat',
    'Škoda',
    'Smart',
    'Subaru',
    'Suzuki',
    'Tesla',
    'Toyota',
    'Volkswagen',
    'Volvo',
  ];

  // ══════════════════════════════════════════════
  //  HELPER METHODS
  // ══════════════════════════════════════════════

  /// Alle Motorrad-Markennamen (sortiert).
  static List<String> get motorcycleBrandNames {
    final names = motorcycleBrands.keys.toList();
    names.sort();
    return names;
  }

  /// Modelle für eine Motorrad-Marke.
  static List<String> motorcycleModelsFor(String brand) =>
      motorcycleBrands[brand] ?? [];

  /// Alle Auto-Markennamen (bereits sortiert).
  static List<String> get carBrandNames => carBrands;

  /// Alle Marken zusammen (Motorrad + Auto, ohne Duplikate).
  static List<String> get allBrandNames {
    final set = <String>{...motorcycleBrands.keys, ...carBrands};
    final list = set.toList();
    list.sort();
    return list;
  }

  /// Prüft ob eine Marke ein Motorrad-Hersteller ist.
  static bool isMotorcycleBrand(String brand) =>
      motorcycleBrands.containsKey(brand);

  /// Prüft ob eine Marke ein Auto-Hersteller ist.
  static bool isCarBrand(String brand) => carBrands.contains(brand);

  /// Sucht Marken die mit dem Suchtext beginnen oder ihn enthalten.
  static List<String> searchBrands(String query, {bool motorcycles = true, bool cars = true}) {
    final q = query.toLowerCase();
    final brands = <String>[];
    if (motorcycles) brands.addAll(motorcycleBrands.keys);
    if (cars) brands.addAll(carBrands);
    // Deduplicate
    final unique = brands.toSet().toList();
    // Sort: starts-with first, then contains
    final startsWith = unique.where((b) => b.toLowerCase().startsWith(q)).toList()..sort();
    final contains = unique.where((b) => b.toLowerCase().contains(q) && !b.toLowerCase().startsWith(q)).toList()..sort();
    return [...startsWith, ...contains];
  }

  /// Sucht Modelle einer Marke.
  static List<String> searchModels(String brand, String query) {
    final models = motorcycleModelsFor(brand);
    if (query.isEmpty) return models;
    final q = query.toLowerCase();
    final startsWith = models.where((m) => m.toLowerCase().startsWith(q)).toList();
    final contains = models.where((m) => m.toLowerCase().contains(q) && !m.toLowerCase().startsWith(q)).toList();
    return [...startsWith, ...contains];
  }

  /// Farben für Fahrzeuge.
  static const vehicleColors = [
    'Schwarz', 'Weiß', 'Grau', 'Silber',
    'Rot', 'Blau', 'Grün', 'Gelb', 'Orange',
    'Braun', 'Gold', 'Violett', 'Matt Schwarz',
    'Mehrfarbig', 'Sonstige',
  ];

  /// Kraftstoff-Typen.
  static const fuelTypes = [
    'Benzin', 'Diesel', 'Elektro', 'Hybrid', 'Plug-in-Hybrid',
  ];

  /// Getriebe-Typen.
  static const transmissionTypes = [
    'Schaltung', 'Automatik', 'Halbautomatik',
  ];
}
