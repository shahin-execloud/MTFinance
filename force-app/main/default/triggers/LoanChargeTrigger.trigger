trigger LoanChargeTrigger on Loan_Charge__c (after insert) { 
    if (Trigger.isAfter && Trigger.isInsert) {
        LoanChargeTriggerHandler.handleAfterInsert(Trigger.new);
    }
}