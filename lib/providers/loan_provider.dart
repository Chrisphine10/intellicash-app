import 'package:flutter/foundation.dart';

import '../data/models/group.dart';
import '../data/models/loan.dart';
import '../data/repositories/loan_repository.dart';

class LoanProvider extends ChangeNotifier {
  LoanProvider(this._repository);

  final LoanRepository _repository;

  List<Loan> _loans = [];
  bool _loading = false;

  List<Loan> get loans => _loans;
  bool get loading => _loading;

  Future<void> load(String groupId) async {
    _loading = true;
    notifyListeners();
    _loans = await _repository.loansForGroup(groupId);
    _loading = false;
    notifyListeners();
  }

  Future<LoanEligibility> eligibility({
    required Group group,
    required String memberId,
  }) =>
      _repository.eligibility(group: group, memberId: memberId);

  Future<Loan> disburse({
    required Group group,
    required String memberId,
    required double principal,
    required DateTime dueDate,
    String? meetingId,
  }) async {
    final loan = await _repository.disburse(
      group: group,
      memberId: memberId,
      principal: principal,
      dueDate: dueDate,
      meetingId: meetingId,
    );
    await load(group.id);
    return loan;
  }

  Future<Loan> repay({
    required Loan loan,
    required double amount,
    String? meetingId,
  }) async {
    final updated = await _repository.repay(
      loan: loan,
      amount: amount,
      meetingId: meetingId,
    );
    await load(loan.groupId);
    return updated;
  }

  Future<Loan?> loanById(String loanId) => _repository.loanById(loanId);

  Future<List<Loan>> loansForMember(String memberId) =>
      _repository.loansForMember(memberId);

  Future<List<LoanRepayment>> repaymentsForLoan(String loanId) =>
      _repository.repaymentsForLoan(loanId);
}
