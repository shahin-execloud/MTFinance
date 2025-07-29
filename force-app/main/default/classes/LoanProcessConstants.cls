public with sharing class LoanProcessConstants {

    // Constants for Loan Process
    public static final String RELEASE_CHARGE_TYPE = 'Release Charge';
    public static final String INTEREST_CHARGE_TYPE = 'Interest Charge';
    public static final String LEGAL_FEE_TYPE = 'Legal Fee';
    public static final String ADMIN_FEE_TYPE = 'Admin Fee';
    public static final Integer DEFAULT_CHARGE_AMOUNT = 500;        
    public static final Integer DEFAULT_TERM = 12; 
    public static final String REPAYMENT_CHARGE_TYPE = 'Repayment Charge';
    public static final Integer ADMIN_FEE_AMOUNT = 300;

    // Prevent instantiation
    private LoanProcessConstants() {
        throw new UnsupportedOperationException('This class cannot be instantiated');   
    }
}