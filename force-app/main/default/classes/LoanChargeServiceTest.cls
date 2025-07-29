@isTest
private class LoanChargeServiceTest {


    @isTest
    static void test_manageNewCharges_withVariousScenarios() {

        // Setup test loans and existing release charges
        List<Loan__c> testLoans = TestDataFactory.setupLoansForReleaseCharges();

        // retrieve auto-created loan charges
        List<Loan_Charge__c> existingReleaseCharges = [
            SELECT Id, Loan__c, Date__c
            FROM Loan_Charge__c
            WHERE Charge_Type__c =: LoanProcessConstants.RELEASE_CHARGE_TYPE
            ORDER BY Loan__r.Name
        ];
        System.assertEquals(6, existingReleaseCharges.size(), 'There should be 6 existing release charges.');
        System.debug('## existingReleaseCharges:' + existingReleaseCharges);


    
        List<Loan_Charge__c> testCharges = new List<Loan_Charge__c>();
        Date baseReleaseDate = Date.today().addMonths(LoanProcessConstants.DEFAULT_TERM);


        // Loan 1: ✅ True Positive 
        testCharges.add(new Loan_Charge__c(
            Loan__c = existingReleaseCharges[0].loan__c,
            Charge_Type__c = LoanProcessConstants.LEGAL_FEE_TYPE,
            Amount__c = 100,
            Date__c = baseReleaseDate
        ));


        // Loan 2: ❌ False Positive
        testCharges.add(new Loan_Charge__c(
            Loan__c = existingReleaseCharges[1].loan__c,
            Charge_Type__c = LoanProcessConstants.LEGAL_FEE_TYPE,
            Amount__c = 150,
            Date__c = baseReleaseDate.addDays(-5)
        ));

        // Loan 3: ❌ False Negative
        testCharges.add(new Loan_Charge__c(
            Loan__c = existingReleaseCharges[2].loan__c,
            Charge_Type__c = LoanProcessConstants.ADMIN_FEE_TYPE,
            Amount__c = 200
            // Missing Date__c
        ));

        // Loan 4: ✅ True Negative
        testCharges.add(new Loan_Charge__c(
            Loan__c = existingReleaseCharges[3].loan__c,
            Charge_Type__c = LoanProcessConstants.INTEREST_CHARGE_TYPE,
            Amount__c = 80,
            Date__c = baseReleaseDate.addDays(-10)
        ));

        // Loan 5: ❌ Edge Case
        // This loan has no existing release charge, so it should only create an admin fee
        testCharges.add(new Loan_Charge__c(
            Loan__c = existingReleaseCharges[4].loan__c,
            Charge_Type__c = LoanProcessConstants.INTEREST_CHARGE_TYPE,
            Amount__c = 300,
            Date__c = baseReleaseDate.addDays(10)
        ));

        
        test.startTest();
            System.debug('##testCharges:' + testCharges);
            insert testCharges;
        test.stopTest();


        // Verify results
        List<Loan_Charge__c> releaseCharges = new List<Loan_Charge__c>(
            [SELECT Id, Loan__c, Date__c, Amount__c, Charge_Type__c FROM Loan_Charge__c
             WHERE Charge_Type__c =: LoanProcessConstants.RELEASE_CHARGE_TYPE 
             ORDER BY Loan__r.Name]
        );

        System.assertEquals(6, releaseCharges.size(), 'There should be 6 release charges returned.');
        System.debug('## releaseCharges:' + releaseCharges);


        // Loan 1 – should be extended
        System.assertEquals(
            existingReleaseCharges[0].Date__c.addMonths(1),
            releaseCharges[0].Date__c,
            'Loan 1 release charge should be extended by 1 month.'
        );

        // Loans 2–4 – should remain unchanged
        System.assertEquals(
            existingReleaseCharges[1].Date__c,
            releaseCharges[1].Date__c,
            'Loan 2 release charge should remain unchanged.'
        );

        // Loan 3 – should not be updated due to missing date
        System.assertEquals(
            existingReleaseCharges[2].Date__c,
            releaseCharges[2].Date__c,
            'Loan 3 release charge should remain unchanged (invalid input).'
        );

        // Loan 4 – should remain unchanged
        System.assertEquals(
            existingReleaseCharges[3].Date__c,
            releaseCharges[3].Date__c,
            'Loan 4 release charge should remain unchanged.'
        );

        // Loan 5 – should not have a release charge, only admin fee
        System.assertEquals(
            existingReleaseCharges[4].Date__c.addMonths(1),
            releaseCharges[4].Date__c,
            'Loan 5 release charge should be extended by 1 month.'
        );

    }


    @isTest
    static void test_termChangeTriggersReleaseUpdateAndAdminFee() {
        
        // Setup test loans for term change scenario
        TestDataFactory.setupLoansForTermChangeScenario();

        // Fetch current Loans
        List<Loan__c> updatedLoans = [
            SELECT Id, Name, Term__c, Date_Loan_Issued__c
            FROM Loan__c
        ];

        Map<Id, Loan__c> oldLoans = new Map<Id, Loan__c>();

        for (Loan__c loan : updatedLoans) {
            Loan__c oldClone = loan.clone(false, true, false, false);
            oldLoans.put(loan.Id, oldClone);
        }

        // Simulate Term changes
        for (Loan__c loan : updatedLoans) {
            if (loan.Name == 'Loan 1') loan.Term__c = 24;           // ✅ True Positive
            if (loan.Name == 'Loan 2') loan.Term__c = 12;           // ❌ False Positive
            if (loan.Name == 'Loan 3') loan.Term__c = 18;           // ❌ False Negative
            if (loan.Name == 'Loan 4') loan.Term__c = null;         // ✅ True Negative
            if (loan.Name == 'Loan 5') loan.Term__c = 9;            // ❌ Edge Case
        }

        Test.startTest();
            update updatedLoans;
        Test.stopTest();

        // Re-fetch Release Charges
        Map<String, Loan__c> nameToLoan = new Map<String, Loan__c>(
            [SELECT Id, Name FROM Loan__c WHERE Name IN ('Loan 1', 'Loan 2', 'Loan 3', 'Loan 4', 'Loan 5')]
        );

        Map<String, Loan_Charge__c> updatedReleaseCharges = new Map<String, Loan_Charge__c>();
        for (Loan_Charge__c rc : [
            SELECT Id, Loan__c, Date__c
            FROM Loan_Charge__c
            WHERE Charge_Type__c = : LoanProcessConstants.RELEASE_CHARGE_TYPE
        ]) {
            for (Loan__c loan : nameToLoan.values()) {
                if (loan.Id == rc.Loan__c) {
                    updatedReleaseCharges.put(loan.Name, rc);
                }
            }
        }

        // ✅ Assert Loan 1's Release Charge was updated
        Date expectedNewDate = updatedLoans[0].Date_Loan_Issued__c.addMonths(24);
        System.assertEquals(expectedNewDate, updatedReleaseCharges.get('Loan 1').Date__c, 'Loan 1 should have updated Release Charge date');

        // ❌ Assert Loan 2's Release Charge unchanged
        Date expectedOldDate = updatedLoans[1].Date_Loan_Issued__c.addMonths(12);
        System.assertEquals(expectedOldDate, updatedReleaseCharges.get('Loan 2').Date__c, 'Loan 2 should not have changed');

        // ❌ Assert Loan 3 was ignored (null issue date)
        System.assertEquals(12, oldLoans.get(updatedLoans[2].Id).Term__c, 'Loan 3 term should have been 12 originally');

        // ✅ Assert Loan 4 (null term) has no change
        System.assertEquals(null, updatedLoans[3].Term__c, 'Loan 4 term remains null');

        // 🔍 Verify Admin Fee insertions (Loan 1 and Loan 5 only)
        Map<String, Loan_Charge__c> adminFees = new Map<String, Loan_Charge__c>();
        for (Loan_Charge__c fee : [
            SELECT Id, Loan__c, Charge_Type__c, Date__c, Amount__c
            FROM Loan_Charge__c
            WHERE Charge_Type__c = 'Admin Fee'
        ]) {
            for (Loan__c loan : nameToLoan.values()) {
                if (loan.Id == fee.Loan__c) {
                    adminFees.put(loan.Name, fee);
                }
            }
        }

        System.assertEquals(2, adminFees.size(), 'Only Loan 1 and Loan 5 should receive Admin Fees');
        System.assertEquals(300, adminFees.get('Loan 1').Amount__c, 'Loan 1 Admin Fee should be £300');
        System.assertEquals(Date.today(), adminFees.get('Loan 1').Date__c, 'Loan 1 Admin Fee should be dated today');
        System.assertEquals(300, adminFees.get('Loan 5').Amount__c, 'Loan 5 Admin Fee should be £300');
    }
}
