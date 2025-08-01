@isTest
private class LoanServiceTest {

    private final static Integer RELEASE_CHARGE_AMOUNT = 500;
    private final static Integer DEFAULT_TERM = 12;
    private final static String RELEASE_CHARGE_TYPE = 'Release Charge';

    @isTest
    static void testCreateReleaseCharges_WhenLoanAlreadyHasLoanCharge_ShouldNotInsert() {
                
        // Setup: Create 10 loan records with different scenarios
        TestDataFactory.setupLoansForReleaseCharges();
        
        // Fetch the test loan already has child charges
        Loan__c existingLoanWithCharges = [
            SELECT Id, Date_Loan_Issued__c, Term__c
            FROM Loan__c WHERE Name = 'Loan #2'
        ];
        // update the existing loan with a new term
        existingLoanWithCharges.Term__c = 24;
        List<Loan__c> loansToUpsert = new List<Loan__c>{existingLoanWithCharges};
        
        // Create 5 new loans 
        for (Integer i = 11; i <= 15; i++) {
            Loan__c loan = new Loan__c(
                Name = 'Loan #' + i,
                Date_Loan_Issued__c = date.today(), // First 6 have issue dates
                Term__c = DEFAULT_TERM // Even-indexed have term
            );
            loansToUpsert.add(loan);
        }

        test.startTest();
            // Call the method to create release charges
            Database.upsert(loansToUpsert, false);
        test.stopTest();    

        // Fetch the test loans including child charges
        List<Loan__c> testLoans = [
            SELECT Id, Date_Loan_Issued__c, Term__c, 
                (
                SELECT Id, Loan__c, Charge_Type__c, Amount__c, Date__c
                FROM Loan_Charges__r
                WHERE Charge_Type__c = :RELEASE_CHARGE_TYPE
                )
            FROM Loan__c
            WHERE Name IN ('Loan #2', 'Loan #11', 'Loan #12', 'Loan #13', 'Loan #14', 'Loan #15')
        ];
        // --- Assertions ---

        // Expecting:
        // Loans #2 → already had a release charge → skip
        // Loans #11, #12, #13, #14, #15 → eligible → create charges
        
        System.assertEquals(6, testLoans.size(), 'Should retrieve 6 loans');

        for (Loan__c loan : testLoans) {
            // check for exactly 1 charge
            System.assertEquals(1, loan.Loan_Charges__r.size(), 'Each loan should have exactly one charge');
            
            // check for charge type
            for (Loan_Charge__c charge : loan.Loan_Charges__r) {
                System.assertEquals(RELEASE_CHARGE_TYPE, charge.Charge_Type__c,
                    'Charge type should be Release Charge');
            }
            System.assertNotEquals(null, loan.Date_Loan_Issued__c, 'Loan should have an issue date');
            System.assertNotEquals(null, loan.Term__c, 'Loan should have a term');
        }

    }
}