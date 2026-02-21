class WizardAssets {
  WizardAssets._();

  static const String carbonBackground = 'assets/images/carbon.png';

  static const List<String> stepHeroImages = [
    'assets/images/1bikerin_welcome.png',
    'assets/images/2bikerin_language.png',
    'assets/images/3bikerin_name.png',
    'assets/images/4bikerin_age.png',
    'assets/images/5bikerin_plz.png',
    'assets/images/6bikerin_email.png',
    'assets/images/7bikerin_riding.png',
    'assets/images/8bikerin_track.png',
    'assets/images/9bike_how_many_bikes.png',
    'assets/images/10bikerin_diy.png',
    'assets/images/11bikerin_picture.png',
    'assets/images/12bikerin_password.png',
    'assets/images/13bikerin_profile.png',
  ];

  static String heroForStep(int stepIndex) {
    if (stepIndex < 0) stepIndex = 0;
    if (stepIndex >= stepHeroImages.length) return stepHeroImages.last;
    return stepHeroImages[stepIndex];
  }
}
