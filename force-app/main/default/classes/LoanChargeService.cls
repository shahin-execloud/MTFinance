public class LoanChargeService {


    @isTest
    static void test_manageNewCharges_respectsAllScenarios() {
        // Arrange: Create 10 test loans using TestDataFactory
        List<Loan__c> testLoans = TestDataFactory.setupLoansForReleaseCharges();
        Date today = Date.today();

        List<Loan_Charge__c> initialReleaseCharges = new List<Loan_Charge__c>();
        List<Loan_Charge__c> newNonReleaseCharges = new List<Loan_Charge__c>();

        for (Integer i = 0; i < testLoans.size(); i++) {
            Loan__c loan = testLoans[i];

           
                // SCENARIOS:
                if (i == 0) {
                    // ✅ True Positive – non-release charge date == release date → should delay
                    newNonReleaseCharges.add(new Loan_Charge__c(
                        Loan__c = loan.Id,
                        Charge_Type__c = 'Late Fee',
                        Amount__c = 100,
                        Date__c = releaseDate
                    ));
                } else if (i == 1) {
                    // ❌ False Positive – charge before release date → no delay
                    newNonReleaseCharges.add(new Loan_Charge__c(
                        Loan__c = loan.Id,
                        Charge_Type__c = 'Late Fee',
                        Amount__c = 120,
                        Date__c = releaseDate.addDays(-5)
                    ));
                } else if (i == 2) {
                    // ❌ False Negative – charge has no date → should be ignored
                    newNonReleaseCharges.add(new Loan_Charge__c(
                        Loan__c = loan.Id,
                        Charge_Type__c = 'Early Settlement',
                        Amount__c = 150
                        // Missing Date__c
                    ));
                } else if (i == 3) {
                    // ✅ True Negative – valid early charge → should not affect release
                    newNonReleaseCharges.add(new Loan_Charge__c(
                        Loan__c = loan.Id,
                        Charge_Type__c = 'Fee Adjustment',
                        Amount__c = 80,
                        Date__c = releaseDate.addDays(-10)
                    ));
                } else if (i == 4) {
                    // ❌ Ignored – charge type = 'Release Charge' → should be ignored
                    newNonReleaseCharges.add(new Loan_Charge__c(
                        Loan__c = loan.Id,
                        Charge_Type__c = LoanProcessConstants.RELEASE_CHARGE_TYPE,
                        Amount__c = 500,
                        Date__c = releaseDate
                    ));
                }
        }

        insert initialReleaseCharges;
        insert newNonReleaseCharges;

        // Act: call the method under test
        Test.startTest();
        LoanChargeService.manageNewCharges(newNonReleaseCharges);
        Test.stopTest();

        // Assert: Re-query updated release charges
        Map<Id, Loan_Charge__c> updatedReleaseMap = new Map<Id, Loan_Charge__c>(
            [SELECT Id, Loan__c, Date__c
             FROM Loan_Charge__c
             WHERE Charge_Type__c = :LoanProcessConstants.RELEASE_CHARGE_TYPE]
        );

        Loan__c truePositiveLoan = testLoans[0];
        Loan__c falsePositiveLoan = testLoans[1];
        Loan__c falseNegativeLoan = testLoans[2];
        Loan__c trueNegativeLoan = testLoans[3];

        Date expectedDelayedDate = truePositiveLoan.Date_Loan_Issued__c.addMonths((Integer)truePositiveLoan.Term__c).addMonths(1);
        Date originalDate = truePositiveLoan.Date_Loan_Issued__c.addMonths((Integer)truePositiveLoan.Term__c);

        // ✅ True Positive → date should be pushed by 1 month
        System.assertEquals(expectedDelayedDate, updatedReleaseMap.get(truePositiveLoan.Id).Date__c, 'True Positive: release date should be extended');

        // ❌ False Positive → no change
        System.assertEquals(originalDate, updatedReleaseMap.get(falsePositiveLoan.Id).Date__c, 'False Positive: release date should not change');

        // ❌ False Negative → invalid input, no change
        System.assertEquals(originalDate, updatedReleaseMap.get(falseNegativeLoan.Id).Date__c, 'False Negative: release date should not change');

        // ✅ True Negative → early charge, no change
        System.assertEquals(originalDate, updatedReleaseMap.get(trueNegativeLoan.Id).Date__c, 'True Negative: release date should not change');
    }
}
