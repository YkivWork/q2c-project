%dw 1.0
%output application/json
%function subString30(aString) (aString when (sizeOf aString) < 31 otherwise aString[0..29])  
---
{
  CREATE_PROJECT_Input: {
    RESTHeader: {
      Responsibility: "XXISG_PA"
    },
    InputParameters: {
      P_PROJECT: {
        SOURCE_SYSTEM: "XXSF", //payload.SOURCE_SYSTEM,
        SOURCE_PROJECT_NUMBER: flowVars.theProject.projectSfdcId,
        PROJECT_NAME: subString30(flowVars.theProject.name),
        DESCRIPTION: flowVars.theProject.name,
        PROJECT_START_DATE: flowVars.theProject.createdAt,
        OPERATING_UNIT_ID: flowVars.theProject.operatingUnitId,
        PRODUCT_TYPE: upper ("Datasite-" ++ flowVars.theProject.productType),
        ORGANIZATION_ID: flowVars.projectOrgId,
        BILLABLE: "Y" //payload.BILLABLE
      }
    }
  }
}
