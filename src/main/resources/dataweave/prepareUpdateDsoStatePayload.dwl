%dw 1.0

%output application/json
---
{
  dataCenter: flowVars.theProject.dataCenter,
  demo: true,

  description: flowVars.theProject.name,
  emailId: '${default.email.address}' when flowVars.theProject.adminEmail == null otherwise flowVars.theProject.adminEmail,
  externalId: flowVars.theProject.projectSfdcId,
  name: flowVars.theProject.name,
  productCode: "MANDA",
  scheduledActivationDate: 0,
  state: "PREP" when flowVars.ariaResponse.state == "Preparation" otherwise "ACTIVE" when flowVars.ariaResponse.state == "Active" otherwise "HIBERNATION" when flowVars.ariaResponse.state == "Hibernation" otherwise "SUSPENDED" when flowVars.ariaResponse.state == "Suspended" otherwise "CLOSED" when flowVars.ariaResponse.state == "Pending Close" otherwise "CLOSED" when flowVars.ariaResponse.state == "Closed" otherwise "UNKNOWN"
}
 