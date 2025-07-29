public class LoanService {

    public static void createReleaseCharges(List<Loan__c> loans) {
        Set<Id> loanIds = new Set<Id>();
        Map<Id, Loan__c> loanMap = new Map<Id, Loan__c>();

        for (Loan__c loan : loans) {
            if (loan.Date_Loan_Issued__c != null && loan.Term__c != null) {
                loanIds.add(loan.Id);
                loanMap.put(loan.Id, loan);
            }
        }

        // Query existing Loan Charges of type 'Release'
        Map<Id, Loan_Charge__c> existingReleaseCharges = new Map<Id, Loan_Charge__c>();
        for (Loan_Charge__c charge : [
            SELECT Id, Loan__c
            FROM Loan_Charge__c
            WHERE Charge_Type__c =: LoanProcessConstants.RELEASE_CHARGE_TYPE AND Loan__c IN :loanIds
            WITH USER_MODE
        ]) {
            existingReleaseCharges.put(charge.Loan__c, charge);
        }

        List<Loan_Charge__c> chargesToInsert = new List<Loan_Charge__c>();

        for (Loan__c loan : loanMap.values()) {
            if (!existingReleaseCharges.containsKey(loan.Id)) {
                Date chargeDate = loan.Date_Loan_Issued__c.addMonths((Integer)loan.Term__c);

                Loan_Charge__c charge = new Loan_Charge__c(
                    Loan__c = loan.Id,
                    Charge_Type__c = LoanProcessConstants.RELEASE_CHARGE_TYPE,
                    Amount__c = LoanProcessConstants.DEFAULT_CHARGE_AMOUNT,
                    Date__c = chargeDate
                );

                chargesToInsert.add(charge);
            }
        }

        if (!chargesToInsert.isEmpty()) {
            insert chargesToInsert;
        }
    }

    public static void handleTermModifications(List<Loan__c> newLoans, Map<Id, Loan__c> oldLoanMap) {
        List<Loan_Charge__c> adminFeesToInsert = new List<Loan_Charge__c>();
        List<Loan_Charge__c> releaseChargesToUpdate = new List<Loan_Charge__c>();
        Set<Id> loanIdsWithChangedTerm = new Set<Id>();

        for (Loan__c loan : newLoans) {
            Loan__c oldLoan = oldLoanMap.get(loan.Id);

            if (loan.Term__c != oldLoan.Term__c && loan.Date_Loan_Issued__c != null) {
                loanIdsWithChangedTerm.add(loan.Id);
            }
        }

        // If no loans have changed terms, exit early
        if (loanIdsWithChangedTerm.isEmpty()) return;

        // Query existing Release Charges and Interest Charges
        Map<Id, Loan_Charge__c> releaseChargesByLoan = new Map<Id, Loan_Charge__c>();
        Map<Id, List<Loan_Charge__c>> interestChargesByLoan = new Map<Id, List<Loan_Charge__c>>();

        for (Loan_Charge__c charge : [
            SELECT Id, Loan__c, Charge_Type__c, Date__c
            FROM Loan_Charge__c
            WHERE Loan__c IN :loanIdsWithChangedTerm
            AND (Charge_Type__c = : LoanProcessConstants.RELEASE_CHARGE_TYPE OR Charge_Type__c = : LoanProcessConstants.INTEREST_CHARGE_TYPE)
        ]) {
            if (charge.Charge_Type__c == LoanProcessConstants.RELEASE_CHARGE_TYPE) {
                releaseChargesByLoan.put(charge.Loan__c, charge);
            } else if (charge.Charge_Type__c == LoanProcessConstants.INTEREST_CHARGE_TYPE) {
                if (!interestChargesByLoan.containsKey(charge.Loan__c)) {
                    interestChargesByLoan.put(charge.Loan__c, new List<Loan_Charge__c>());
                }
                interestChargesByLoan.get(charge.Loan__c).add(charge);
            }
        }

        // Update Release Charges and create Admin Fees
        for (Loan__c loan : newLoans) {
            // Skip if the loan does not have a changed term
            if (!loanIdsWithChangedTerm.contains(loan.Id)) continue;

            // Update Release Charge Date
            Loan_Charge__c release = releaseChargesByLoan.get(loan.Id);
            if (release != null && loan.Term__c != null) {
                release.Date__c = loan.Date_Loan_Issued__c.addMonths((Integer)loan.Term__c);
                releaseChargesToUpdate.add(release);
            }

            // Create Admin Fee
            Loan_Charge__c adminFee = new Loan_Charge__c(
                Loan__c = loan.Id,
                Charge_Type__c = LoanProcessConstants.ADMIN_FEE_TYPE,
                Amount__c = LoanProcessConstants.ADMIN_FEE_AMOUNT,
                Date__c = Date.today()
            );

            adminFeesToInsert.add(adminFee);
        }
        
        // Update Release Charges and insert Admin Fees
        if (!releaseChargesToUpdate.isEmpty()) {
            update releaseChargesToUpdate;
        }

        if (!adminFeesToInsert.isEmpty()) {
            insert adminFeesToInsert;
        }
    }
}