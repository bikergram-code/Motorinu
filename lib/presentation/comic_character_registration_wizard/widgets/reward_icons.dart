import 'package:flutter/material.dart';

/// Central icon mapping for rewards.
/// Keep BOTH APIs:
/// - forAgeSeal(String label)  -> used by RewardToast
/// - forAge(int age)           -> optional usage
class RewardIcons {
  static IconData forAgeSeal(String label) {
    switch (label) {
      case 'Baby Biker':
        return Icons.toys;
      case 'Pocket Rocket':
        return Icons.rocket_launch;
      case 'Moped Rebell':
        return Icons.moped;
      case 'Road Ready':
        return Icons.sports_motorsports;
      case 'Asphalt Junkie':
        return Icons.emoji_events; // trophy
      case 'Touren König':
        return Icons.tour; // tour icon
      case 'Asphalt Veteran':
        return Icons.military_tech; // medal
      case 'Oldschool Legend':
        return Icons.workspace_premium; // crown-ish
      case 'Hardcore Biker':
        return Icons.local_fire_department;
      case 'Grabsteher Biker':
        return Icons.church; // no "grave" icon exists in Material
      default:
        return Icons.verified;
    }
  }

  static IconData forAge(int age) {
    if (age < 12) return Icons.toys;
    if (age < 16) return Icons.pedal_bike;
    if (age < 18) return Icons.moped;
    if (age < 25) return Icons.sports_motorsports;
    if (age < 35) return Icons.emoji_events;
    if (age < 50) return Icons.military_tech;
    if (age < 65) return Icons.workspace_premium;
    if (age < 80) return Icons.local_fire_department;
    if (age < 100) return Icons.whatshot;
    return Icons.church;
  }

  static IconData forStepBadge(String badge) {
    switch (badge) {
      case 'Road Rookie':
        return Icons.directions_bike;
      case 'Name Claimed':
        return Icons.edit;
      case 'Age Verified':
        return Icons.verified_user;
      case 'Inbox Ready':
        return Icons.mail;
      case 'Track Curious':
        return Icons.flag;
      case 'Garage Mechanic':
        return Icons.build;
      case 'Selfie Ready':
        return Icons.camera_alt;
      case 'Lock & Loaded':
        return Icons.lock;
      case 'Crew Member':
        return Icons.groups;
      default:
        return Icons.emoji_events;
    }
  }
}
