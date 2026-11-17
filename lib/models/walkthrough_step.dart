enum WalkthroughStepId {
  welcome,
  hudTour,
  selectGarden,
  enterHabitatCare,
  feedDog,
  backFromHabitat,
  selectFactory,
  enterFactory,
  bakeRecipe,
  speedUpBaking,
  collectKibble,
  backFromFactory,
  shopAndGoals,
  graduation,
}

enum WalkthroughArrowDirection {
  none,
  down,
  up,
  left,
  right,
}

class WalkthroughTargets {
  static const String hudResources = 'hud_resources';
  static const String hudCareDog = 'hud_care_dog';
  static const String hudMakeFood = 'hud_make_food';
  static const String hudBuild = 'hud_build';
  static const String careDogStation = 'care_dog_station';
  static const String careFeedButton = 'care_feed_button';
  static const String careBackButton = 'care_back_button';
  static const String factoryBakeButton = 'factory_bake_button';
  static const String factorySpeedUpButton = 'factory_speed_up_button';
  static const String factoryCollectButton = 'factory_collect_button';
  static const String factoryBackButton = 'factory_back_button';
}

class WalkthroughStep {
  final WalkthroughStepId id;
  final String title;
  final String message;
  final String requiredRoute;
  final String? targetKeyId;
  final String? highlightAreaKeyId;
  final String? worldTargetHabitatId;
  final WalkthroughArrowDirection arrowDirection;
  final bool requireAction;
  final String? ctaLabel;
  final bool isCenterModal;

  const WalkthroughStep({
    required this.id,
    required this.title,
    required this.message,
    required this.requiredRoute,
    this.targetKeyId,
    this.highlightAreaKeyId,
    this.worldTargetHabitatId,
    this.arrowDirection = WalkthroughArrowDirection.none,
    this.requireAction = false,
    this.ctaLabel,
    this.isCenterModal = false,
  });

  static const List<WalkthroughStep> steps = [
    WalkthroughStep(
      id: WalkthroughStepId.welcome,
      title: 'WELCOME TO DOGTOPIA!',
      message:
          "Greetings, Keeper! I'm Merlin the Dog Wizard. Let me give you a quick tour so your puppy paradise thrives!",
      requiredRoute: 'world',
      isCenterModal: true,
      ctaLabel: "LET'S GO!",
    ),
    WalkthroughStep(
      id: WalkthroughStepId.hudTour,
      title: 'YOUR RESOURCES',
      message:
          'Keep an eye on your Star Crystals, Paw Coins, and Kibble up here. Your Level & XP bar sits on the top-left!',
      requiredRoute: 'world',
      targetKeyId: WalkthroughTargets.hudResources,
      arrowDirection: WalkthroughArrowDirection.up,
      ctaLabel: 'NEXT',
    ),
    WalkthroughStep(
      id: WalkthroughStepId.selectGarden,
      title: 'VISIT YOUR HABITAT',
      message:
          'Your pup Winston is waiting! Tap your Garden Park on the island to open its controls.',
      requiredRoute: 'world',
      worldTargetHabitatId: 'hab_starter_garden',
      arrowDirection: WalkthroughArrowDirection.down,
      requireAction: true,
    ),
    WalkthroughStep(
      id: WalkthroughStepId.enterHabitatCare,
      title: 'MEET WINSTON',
      message:
          "Tap Winston's portrait on the bar below to step inside the habitat and care for him!",
      requiredRoute: 'world',
      targetKeyId: WalkthroughTargets.hudCareDog,
      arrowDirection: WalkthroughArrowDirection.down,
      requireAction: true,
    ),
    WalkthroughStep(
      id: WalkthroughStepId.feedDog,
      title: 'FEED YOUR PUP',
      message:
          'Keep feeding Winston until your Kibble runs out! Watch him grow and level up with FEED or FEED x4.',
      requiredRoute: 'habitat',
      targetKeyId: WalkthroughTargets.careFeedButton,
      highlightAreaKeyId: WalkthroughTargets.careDogStation,
      arrowDirection: WalkthroughArrowDirection.left,
      requireAction: true,
    ),
    WalkthroughStep(
      id: WalkthroughStepId.backFromHabitat,
      title: 'OUT OF KIBBLE!',
      message:
          "Winston loved that, and now we're out of Kibble! Tap BACK TO ISLAND to bake more at the Dogfood Factory.",
      requiredRoute: 'habitat',
      targetKeyId: WalkthroughTargets.careBackButton,
      arrowDirection: WalkthroughArrowDirection.up,
      requireAction: true,
    ),
    WalkthroughStep(
      id: WalkthroughStepId.selectFactory,
      title: 'DOGFOOD FACTORY',
      message:
          'Dogs need Kibble to grow! Tap your Dogfood Factory on the island to select it.',
      requiredRoute: 'world',
      worldTargetHabitatId: 'hab_starter_factory',
      arrowDirection: WalkthroughArrowDirection.down,
      requireAction: true,
    ),
    WalkthroughStep(
      id: WalkthroughStepId.enterFactory,
      title: 'OPEN THE BAKERY',
      message:
          'Tap MAKE FOOD below to enter the Kibble Bakery and pick a recipe.',
      requiredRoute: 'world',
      targetKeyId: WalkthroughTargets.hudMakeFood,
      arrowDirection: WalkthroughArrowDirection.down,
      requireAction: true,
    ),
    WalkthroughStep(
      id: WalkthroughStepId.bakeRecipe,
      title: 'BAKE YOUR FIRST KIBBLE',
      message:
          'Tap MAKE FOOD on a recipe to start baking fresh Kibble in the oven!',
      requiredRoute: 'factory',
      targetKeyId: WalkthroughTargets.factoryBakeButton,
      arrowDirection: WalkthroughArrowDirection.down,
      requireAction: true,
    ),
    WalkthroughStep(
      id: WalkthroughStepId.speedUpBaking,
      title: 'SKIP THE WAIT WITH GEMS',
      message:
          "Don't want to wait? Tap SPEED UP to use a Star Crystal and finish baking right away!",
      requiredRoute: 'factory',
      targetKeyId: WalkthroughTargets.factorySpeedUpButton,
      arrowDirection: WalkthroughArrowDirection.down,
      requireAction: true,
    ),
    WalkthroughStep(
      id: WalkthroughStepId.collectKibble,
      title: 'COLLECT YOUR KIBBLE',
      message:
          'Fresh out of the oven! Tap COLLECT KIBBLE to add it to your food supply.',
      requiredRoute: 'factory',
      targetKeyId: WalkthroughTargets.factoryCollectButton,
      arrowDirection: WalkthroughArrowDirection.down,
      requireAction: true,
    ),
    WalkthroughStep(
      id: WalkthroughStepId.backFromFactory,
      title: 'KIBBLE STOCKED!',
      message:
          'Awesome! Tap BACK TO ISLAND for one final tip from me.',
      requiredRoute: 'factory',
      targetKeyId: WalkthroughTargets.factoryBackButton,
      arrowDirection: WalkthroughArrowDirection.up,
      requireAction: true,
    ),
    WalkthroughStep(
      id: WalkthroughStepId.shopAndGoals,
      title: 'BUILD & DAILY GOALS',
      message:
          'Use BUILD to buy new habitats, facilities, and dogs — and check GOALS on the left for bonus rewards!',
      requiredRoute: 'world',
      targetKeyId: WalkthroughTargets.hudBuild,
      arrowDirection: WalkthroughArrowDirection.down,
      ctaLabel: 'NEXT',
    ),
    WalkthroughStep(
      id: WalkthroughStepId.graduation,
      title: 'YOU ARE READY!',
      message:
          "You've mastered the basics of Dogtopia! Claim my wizard's starter gift and build the ultimate puppy island!",
      requiredRoute: 'world',
      isCenterModal: true,
      ctaLabel: 'CLAIM & PLAY!',
    ),
  ];
}
