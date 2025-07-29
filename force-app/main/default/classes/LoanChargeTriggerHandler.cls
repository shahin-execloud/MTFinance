public class LoanChargeTriggerHandler {
    public static void handleAfterInsert(List<Loan_Charge__c> newCharges) {
        LoanChargeService.manageNewCharges(newCharges);
    }
}