public class LoanChargeService {


   public static void manageNewCharges(List<Loan_Charge__c> newCharges) {
        if (newCharges.isEmpty()) return;

        Set<Id> affectedLoanIds = new Set<Id>();

        // Collect Loan IDs for non-Release charges only
        for (Loan_Charge__c charge : newCharges) {
            if (charge.Charge_Type__c != LoanProcessConstants.RELEASE_CHARGE_TYPE && charge.Loan__c != null && charge.Date__c != null) {
                affectedLoanIds.add(charge.Loan__c);
            }
        }

        if (affectedLoanIds.isEmpty()) return;

        // Query existing Release Charges for these loans
        Map<Id, Loan_Charge__c> releaseChargesByLoan = new Map<Id, Loan_Charge__c>();
        for (Loan_Charge__c release : [
            SELECT Id, Loan__c, Date__c
            FROM Loan_Charge__c
            WHERE Charge_Type__c =: LoanProcessConstants.RELEASE_CHARGE_TYPE AND Loan__c IN :affectedLoanIds
        ]) {
            releaseChargesByLoan.put(release.Loan__c, release);
        }

        // Adjust Release Charge dates if necessary
        List<Loan_Charge__c> releaseUpdates = new List<Loan_Charge__c>();

        for (Loan_Charge__c charge : newCharges) {
            // Skip if it's a Release Charge or if Loan or Date is null
            if (charge.Charge_Type__c == LoanProcessConstants.RELEASE_CHARGE_TYPE || charge.Loan__c == null || charge.Date__c == null) continue;

            Loan_Charge__c release = releaseChargesByLoan.get(charge.Loan__c);
            if (release != null && release.Date__c != null && charge.Date__c >= release.Date__c) {
                release.Date__c = release.Date__c.addMonths(1);
                releaseUpdates.add(release);
            }
        }

        if (!releaseUpdates.isEmpty()) {
            update releaseUpdates;
        }
    }
}
