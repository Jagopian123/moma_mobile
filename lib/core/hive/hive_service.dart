import 'package:hive_flutter/hive_flutter.dart';
import 'models/wallet_model.dart';
import 'models/transaction_model.dart';
import 'models/category_model.dart';
import 'models/budget_model.dart';
import 'models/financial_plan_model.dart';
import 'models/debt_model.dart';
import 'models/investment_model.dart';

class HiveService {
  static const String walletBox = 'wallets';
  static const String transactionBox = 'transactions';
  static const String categoryBox = 'categories';
  static const String budgetBox = 'budgets';
  static const String financialPlanBox = 'financial_plans';
  static const String debtBox = 'debts';
  static const String investmentBox = 'investments';
  static const String userBox = 'user';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register semua adapter manual (tidak perlu build_runner)
    Hive.registerAdapter(WalletModelAdapter());
    Hive.registerAdapter(TransactionModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(BudgetModelAdapter());
    Hive.registerAdapter(FinancialPlanModelAdapter());
    Hive.registerAdapter(ContributionModelAdapter());
    Hive.registerAdapter(DebtModelAdapter());
    Hive.registerAdapter(DebtPaymentModelAdapter());
    Hive.registerAdapter(InvestmentModelAdapter());

    // Buka semua box sekaligus
    await Future.wait([
      Hive.openBox<WalletModel>(walletBox),
      Hive.openBox<TransactionModel>(transactionBox),
      Hive.openBox<CategoryModel>(categoryBox),
      Hive.openBox<BudgetModel>(budgetBox),
      Hive.openBox<FinancialPlanModel>(financialPlanBox),
      Hive.openBox<DebtModel>(debtBox),
      Hive.openBox<InvestmentModel>(investmentBox),
      Hive.openBox(userBox),
    ]);
  }

  // Getter shortcut untuk tiap box
  static Box<WalletModel> get wallets => Hive.box<WalletModel>(walletBox);
  static Box<TransactionModel> get transactions =>
      Hive.box<TransactionModel>(transactionBox);
  static Box<CategoryModel> get categories =>
      Hive.box<CategoryModel>(categoryBox);
  static Box<BudgetModel> get budgets => Hive.box<BudgetModel>(budgetBox);
  static Box<FinancialPlanModel> get financialPlans =>
      Hive.box<FinancialPlanModel>(financialPlanBox);
  static Box<DebtModel> get debts => Hive.box<DebtModel>(debtBox);
  static Box<InvestmentModel> get investments =>
      Hive.box<InvestmentModel>(investmentBox);
  static Box get user => Hive.box(userBox);
}
