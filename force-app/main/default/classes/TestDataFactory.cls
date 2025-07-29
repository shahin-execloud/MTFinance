@isTest
public with sharing class TestDataFactory {

    // Utility for Scenario A
    public static List<Loan__c> setupLoansForReleaseCharges() {
        // insert loans
        List<Loan__c> testLoans = new List<Loan__c>();
        Date today = Date.today();          
        // Create 10 loans with varied eligibility for release charges
        for (Integer i = 1; i <= 10; i++) {
            Loan__c loan = new Loan__c(
                Name = 'Loan #' + i,
                Date_Loan_Issued__c = (i <= 6) ? today : null, // First 6 have issue dates
                Term__c = (i <= 6) ? LoanProcessConstants.DEFAULT_TERM : null   // First 6 have term
            );
            testLoans.add(loan);    
        }

        insert testLoans;
        return testLoans;
    }

    // Utility for Scenario B
    public static List<Loan__c> setupLoansForTermChangeScenario() {

        List<Loan__c> testLoans = new List<Loan__c>();

        // Loan 1: ✅ True Positive — change in term, valid issue date → should update & insert fee
        testLoans.add(new Loan__c(Name = 'Loan 1', Term__c = 12, Date_Loan_Issued__c = Date.today().addYears(-1)));

        // Loan 2: ❌ False Positive — no change in term → should be ignored
        testLoans.add(new Loan__c(Name = 'Loan 2', Term__c = 12, Date_Loan_Issued__c = Date.today().addYears(-1)));

        // Loan 3: ❌ False Negative — term changed but missing issue date → should not update or insert
        testLoans.add(new Loan__c(Name = 'Loan 3', Term__c = 12));

        // Loan 4: ✅ True Negative — null term before & after → ignored safely
        testLoans.add(new Loan__c(Name = 'Loan 4', Term__c = null));

        // Loan 5: ❌ Edge Case — term changed, no existing release charge → only admin fee inserted
        testLoans.add(new Loan__c(Name = 'Loan 5', Term__c = 6, Date_Loan_Issued__c = Date.today().addYears(-2)));

        insert testLoans;
        return testLoans;
    }
}