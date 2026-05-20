class PlanLimits {
  final bool isPro;

  const PlanLimits({required this.isPro});

  static const int unlimited = 9999;

  int get maxBudgets        => isPro ? unlimited : 3;
  int get maxFinancialPlans => isPro ? unlimited : 2;
  int get maxDebts          => isPro ? unlimited : 5;
  int get maxWallets        => isPro ? unlimited : 5;
  int get maxSubscriptions  => isPro ? unlimited : 5;
  int get maxInvestments    => isPro ? unlimited : 3;
  int get maxInsights       => isPro ? unlimited : 3;

  bool canAdd(int currentCount, int max) => currentCount < max;

  bool get canAddBudget        => canAdd(0, maxBudgets);
  bool get unlimitedExport     => isPro;
  bool get autoBackup          => isPro;

  bool canAddBudgets(int current)       => canAdd(current, maxBudgets);
  bool canAddFinancialPlan(int current) => canAdd(current, maxFinancialPlans);
  bool canAddDebt(int current)          => canAdd(current, maxDebts);
  bool canAddWallet(int current)        => canAdd(current, maxWallets);
  bool canAddSubscription(int current)  => canAdd(current, maxSubscriptions);
  bool canAddInvestment(int current)    => canAdd(current, maxInvestments);
}
