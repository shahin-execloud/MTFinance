trigger LoanTrigger on Loan__c (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        LoanTriggerHandler.handleAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        LoanTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}