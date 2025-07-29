public with sharing class LoanTriggerHandler {
    public static void handleAfterInsert(List<Loan__c> newLoans) {
        LoanService.createReleaseCharges(newLoans);
    }
    public static void handleAfterUpdate(List<Loan__c> newLoans, Map<Id, Loan__c> oldLoanMap) {
        LoanService.handleTermModifications(newLoans, oldLoanMap);
    }
}