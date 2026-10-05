/// Adapts legacy Wallet SDK wording at the presentation boundary.
/// Protocol names, SDK return values, and persisted data remain unchanged.
String employeeFacingText(String value) => value
    .replaceAll('Rewards is ', 'Wellness Points are ')
    .replaceAll('Builder Rewards', 'Wellness Points')
    .replaceAll('Rewards', 'Wellness Points')
    .replaceAll('Builder', 'Employee')
    .replaceAll('App Master', 'Wellness Admin')
    .replaceAll('distributor', 'administrator')
    .replaceAll('Distributor', 'Administrator');
