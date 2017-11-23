%dw 1.0
%output application/xml
%namespace lit urn:client:api:wsdl:document/literal_wrapped:vers:11.0:aria_complete_m_api
%namespace soap http://schemas.xmlsoap.org/soap/envelope/

//1 - Add name and value for a new plan instance field.
//2 - Replace value of an existing plan instance field.
//3 - Remove the value of an existing plan instance field, note that if the plan instance field is required based on the field definition, the Replace directive should be used.
//4 - Remove the name and value of an existing plan instance field from the plan instance.

// See reference at
// https://developer.ariasystems.net/Aria_Crescendo_core_api/update_acct_plan_multi_m

%function asDate(field) field as :date when field != null otherwise null
%var Today = now as :date {format: "yyyy-MM-dd"}


%var projectStatus = flowVars.theProject.projectStatus

%var continuationDate = asDate(flowVars.theProject.continuationDate)
%var inContinuation = false when continuationDate == null otherwise Today >= continuationDate

%var Active = p('aria.project_status.active')
%var BuildPeriod = p('aria.project_status.build_period')
%var Preparation = 'Preparation'
%var PendingClose = 'Pending Close'
%var Hibernation = p('aria.project_status.hibernation')
%var Closed = p('aria.project_status.closed')
%var ClosureRequest = p('aria.project_status.closure_requested')
%var Suspended = p('aria.project_status.suspended')
%var HostingLabel = 'HOSTING_LABEL'
%var HistoricalEffectiveDate = 'HISTORICAL_EFFECTIVE_DATE'

// I don't know a better name, so we are gonig to use "ongoing"
%var projectStillOngoing = [Active, Hibernation] contains projectStatus

%function createPlanInstanceField(key, value) {} when value == null or value == ''
 otherwise plan_instance_field_update_row: { plan_instance_field_name: key, plan_instance_field_value: value, plan_instance_field_directive: 2 }

%function createPlanInstanceFieldIfNotExisting(key, value, hasExistingValue) {} when value == null or value == '' or hasExistingValue
 otherwise plan_instance_field_update_row: { plan_instance_field_name: key, plan_instance_field_value: value, plan_instance_field_directive: 1 }

%function createPlanInstanceFieldCheckExisting(key, value, hasExistingValue) {} when value == null or value == ''
 otherwise plan_instance_field_update_row: { plan_instance_field_name: key, plan_instance_field_value: value, plan_instance_field_directive: 2 when hasExistingValue otherwise 1 }

%function createPlanInstanceFieldOverride(key, value, hasExistingValue, overrideValue) {} when value == null or value == ''
 otherwise plan_instance_field_update_row: { plan_instance_field_name: key, plan_instance_field_value: value, plan_instance_field_directive: overrideValue }

%function createPlanInstanceFieldHistoricalEffectiveDate(value, currentValue) {} when value == currentValue
 otherwise plan_instance_field_update_row: { plan_instance_field_name: HistoricalEffectiveDate, plan_instance_field_value: value when currentValue == null otherwise currentValue ++ ', ' ++ value, plan_instance_field_directive: 1 when value == null otherwise 2}

%function createSuppField(key, value) {} when value == null or value == '' otherwise supp_field_row: { supp_field_name: key, supp_field_value: value }
%function basedOnLegalName(value) 'AAHCM5122B' when value == '010' otherwise 'AAHCM0547Q' when value == '071' otherwise null

//%function findSize(value) 2 when sizeOf(payload.message) > 3 otherwise sizeOf(payload.message) - 1
//This is ugly, I can't find a better way, looks like some up and coming versions can do this much easier like [0 to findTheIndex(value)]
//where findTheIndex is a function to figure out what size we want to use

%function trimToThree(value) value[0..2] when (sizeOf value) > 2 otherwise value[0..1] when (sizeOf value) == 2 otherwise value[0] when (sizeOf value) == 1 otherwise null

%function splitUpLegalName() flowVars.theProject.legalEntity splitBy '-'
%var legalEntityId = trim ( splitUpLegalName()[0] default '999' )
%var legalEntityName = trim ( splitUpLegalName()[1] default 'NOT PROVIDED' )

%var invoiceMapping = lookup('lookupFromInvoiceMappingFlow', { currency: flowVars.theProject.currency, legalEntity: legalEntityId, operatingUnitId: flowVars.theProject.operatingUnitId })

//Look at what duplication we can remove from the create side too.
%function findEntitlement(value) lookup('getAriaEntitlementsFromTemplate', {}).supplemental_obj_fields[?( $.field_name == value )][0].field_value[0]
%function projEntitlement()
 findEntitlement('PREPARATION_ENTITLEMENTS') when projectStatus == 'Build Period' otherwise
 findEntitlement('ACTIVE_ENTITLEMENTS') when projectStatus == 'Active' otherwise
 findEntitlement('PENDING_CLOSE_ENTITLEMENTS') when projectStatus == 'Closure Request' otherwise
 findEntitlement('CLOSED_ENTITLEMENTS') when projectStatus == 'Closed' otherwise
 findEntitlement('HIBERNATION_ENTITLEMENTS') when projectStatus == 'Hibernation' otherwise
 findEntitlement('SUSPENDED_ENTITLEMENTS') when projectStatus == 'Suspended' otherwise
 ''

%var hasMinimumFee = (sizeOf flowVars.theProject.minimumFee default '') > 0

%var contractCustomer = (flowVars.theProject.contractCustomer default '')
%var contractCustomerArray = contractCustomer splitBy ','
%var contractCustomerSize = sizeOf ( contractCustomerArray )
%var contractCustomer1 = '' when contractCustomerSize < 1 otherwise trim contractCustomerArray[0]
%var contractCustomer2 = '' when contractCustomerSize < 2 otherwise trim contractCustomerArray[1]
%var contractCustomer3 = '' when contractCustomerSize < 3 otherwise trim contractCustomerArray[2]

%var billedByPages = flowVars.theProject.unitOfMeasure == 'Page'
%var billedByMBs = flowVars.theProject.unitOfMeasure == 'MB'
%var billedByGBs = flowVars.theProject.unitOfMeasure == 'GB'

%var hibernateOrInContinuation = ( projectStatus == Hibernation ) or ( projectStatus == Active and inContinuation )

%var hostingLabelValue = 'In Continuation' when inContinuation otherwise 'In Hibernation' when projectStatus == Hibernation otherwise null

%var billedByPagesHosted = hibernateOrInContinuation and billedByPages
%var billedByMBsHosted = hibernateOrInContinuation and billedByMBs
%var billedByGBsHosted = hibernateOrInContinuation and billedByGBs
%var specialMediaHosted = hibernateOrInContinuation

%var billedByPagesUploaded = ( not billedByPagesHosted ) and billedByPages
%var billedByMBsUploaded = ( not billedByMBsHosted ) and billedByMBs
%var billedByGBsUploaded = ( not billedByGBsHosted ) and billedByGBs

%var pagesUploadedPlanId = 'Pages_Uploaded'
%var mbsUploadedPlanId = 'MBs_Uploaded'
%var gbsUploadedPlanId = 'GBs_Uploaded'
%var pagesHostedPlanId = 'Pages_Hosted'
%var mbsHostedPlanId = 'MBs_Hosted'
%var gbsHostedPlanId = 'GBs_Hosted'

%var billedByUploaded = billedByPagesUploaded or billedByMBsUploaded or billedByGBsUploaded
%var billedByHosted = billedByPagesHosted or billedByMBsHosted or billedByGBsHosted

%var clientPlanName = pagesUploadedPlanId when billedByPagesUploaded otherwise mbsUploadedPlanId when billedByMBsUploaded otherwise gbsUploadedPlanId when billedByGBsUploaded otherwise null
%var clientServiceName =
 'PgUploaded' when billedByPagesUploaded otherwise
 'MBUploaded' when billedByMBsUploaded otherwise
 'GBUploaded' when billedByGBsUploaded otherwise
 'PgHosted' when billedByPagesHosted otherwise
 'MBHosted' when billedByMBsHosted otherwise
 'GBHosted' when billedByGBsHosted otherwise
 null

%var SpecialMediaPlanId = 'Special_Media'
%var specialMediaPlanName = 'SMUploaded'

%var SpecialMediaHostedPlanId = 'Special_Media_Hosted'
%var specialMediaHostedPlanName = 'SMHosted'

%var clientServiceNameMinimumFee = 'PgMinimumFee' when billedByPages otherwise 'MBMinimumFee' when billedByMBs otherwise 'GBMinimumFee' when billedByGBs otherwise null
%var customRatesForHosted = {
  custom_rates_row: {
    custom_rate_client_service_id: clientServiceName,
    custom_rate_seq_no: 1,
    custom_rate_from_unit: 1,
    custom_rate_per_unit: flowVars.theProject.hibernationRate when projectStatus == Hibernation otherwise flowVars.theProject.continuationRate
  }
}
%var customRatesForUploaded = {
      custom_rates_row: {
        custom_rate_client_service_id: clientServiceNameMinimumFee,
        custom_rate_seq_no: 1,
        custom_rate_from_unit: 1,
        custom_rate_per_unit: flowVars.theProject.minimumFee
      },
      (custom_rates_row: {
        custom_rate_client_service_id: clientServiceName,
        custom_rate_seq_no: 1,
        custom_rate_from_unit: 1,
        custom_rate_to_unit: flowVars.theProject.tier1UpperLimit,
        custom_rate_per_unit: flowVars.theProject.tier1Rate
      }) when flowVars.theProject.tier1Rate != null,
      (custom_rates_row: {
        custom_rate_client_service_id: clientServiceName,
        custom_rate_seq_no: 2,
        custom_rate_from_unit: flowVars.theProject.tier1UpperLimit + 1,
        custom_rate_to_unit: flowVars.theProject.tier2UpperLimit,
        custom_rate_per_unit: flowVars.theProject.tier2Rate
      }) when flowVars.theProject.tier2Rate != null,
      (custom_rates_row: {
        custom_rate_client_service_id: clientServiceName,
        custom_rate_seq_no: 3,
        custom_rate_from_unit: flowVars.theProject.tier2UpperLimit + 1,
        custom_rate_to_unit: flowVars.theProject.tier3UpperLimit,
        custom_rate_per_unit: flowVars.theProject.tier3Rate
      }) when flowVars.theProject.tier3Rate != null,
      (custom_rates_row: {
        custom_rate_client_service_id: clientServiceName,
        custom_rate_seq_no: 4,
        custom_rate_from_unit: flowVars.theProject.tier3UpperLimit + 1,
        custom_rate_to_unit: flowVars.theProject.tier4UpperLimit,
        custom_rate_per_unit: flowVars.theProject.tier4Rate
      }) when flowVars.theProject.tier4Rate != null,
      (custom_rates_row: {
        custom_rate_client_service_id: clientServiceName,
        custom_rate_seq_no: 5,
        custom_rate_from_unit: flowVars.theProject.tier4UpperLimit + 1,
        custom_rate_to_unit: flowVars.theProject.tier5UpperLimit,
        custom_rate_per_unit: flowVars.theProject.tier5Rate
      }) when flowVars.theProject.tier5Rate != null,
      (custom_rates_row: {
        custom_rate_client_service_id: clientServiceName,
        custom_rate_seq_no: 6,
        custom_rate_from_unit: flowVars.theProject.tier5UpperLimit + 1,
        custom_rate_to_unit: flowVars.theProject.tier6UpperLimit,
        custom_rate_per_unit: flowVars.theProject.tier6Rate
      }) when flowVars.theProject.tier6Rate != null,
      (custom_rates_row: {
        custom_rate_client_service_id: clientServiceName,
        custom_rate_seq_no: 7,
        custom_rate_from_unit: flowVars.theProject.tier6UpperLimit + 1,
        custom_rate_to_unit: flowVars.theProject.tier7UpperLimit,
        custom_rate_per_unit: flowVars.theProject.tier7Rate
      }) when flowVars.theProject.tier7Rate != null,
      (custom_rates_row: {
        custom_rate_client_service_id: clientServiceName,
        custom_rate_seq_no: 8,
        custom_rate_from_unit: flowVars.theProject.tier7UpperLimit + 1,
        custom_rate_to_unit: flowVars.theProject.tier8UpperLimit,
        custom_rate_per_unit: flowVars.theProject.tier8Rate
      }) when flowVars.theProject.tier8Rate != null,
      (custom_rates_row: {
        custom_rate_client_service_id: clientServiceName,
        custom_rate_seq_no: 9,
        custom_rate_from_unit: flowVars.theProject.tier8UpperLimit + 1,
        custom_rate_to_unit: flowVars.theProject.tier9UpperLimit,
        custom_rate_per_unit: flowVars.theProject.tier9Rate
      }) when flowVars.theProject.tier9Rate != null,
      (custom_rates_row: {
        custom_rate_client_service_id: clientServiceName,
        custom_rate_seq_no: 10,
        custom_rate_from_unit: flowVars.theProject.tier9UpperLimit + 1,
        custom_rate_per_unit: flowVars.theProject.tier10Rate
      }) when flowVars.theProject.tier10Rate != null
    }

%function projectAndPlanStatusMapping()
 { masterPlanStatus: 32, suppPlanStatus: 32, projectStatus: Preparation } when projectStatus == BuildPeriod otherwise
 { masterPlanStatus: 1, suppPlanStatus: 1, projectStatus: projectStatus } when projectStatus == Active otherwise
 { masterPlanStatus: 2, suppPlanStatus: 2, projectStatus: PendingClose } when projectStatus == ClosureRequest otherwise
 { masterPlanStatus: -3, suppPlanStatus: -3, projectStatus: projectStatus } when projectStatus == Closed otherwise
 { masterPlanStatus: 1, suppPlanStatus: 1, projectStatus: projectStatus } when projectStatus == Hibernation otherwise
 { masterPlanStatus: -1, suppPlanStatus: -1, projectStatus: projectStatus } when projectStatus == Suspended otherwise
 { masterPlanStatus: 99, suppPlanStatus: 99, projectStatus: 'NOT KNOWN' }

//QTC-444 and QTC-477
%var masterPlanStatus = null when projectStatus == Active or projectStatus == ClosureRequest otherwise projectAndPlanStatusMapping().masterPlanStatus
%var suppPlanStatus = null when projectStatus == Active or projectStatus == ClosureRequest otherwise projectAndPlanStatusMapping().suppPlanStatus

// I had issues where this was working in munit, but was failing during runtime (because at runtime it was seen as a string)
// I could have overrode the mimeType in the flow, but I decided to have it here. Not sure if it is better/worse
%var ariaAcctDetails = read(flowVars.ariaAcctDetails, 'application/xml').Envelope.Body.get_acct_details_all_mResponseElement
%var existingPlans = ariaAcctDetails.master_plans_info.*supp_plans_info
%var pagesUploadPlan = existingPlans[?( $.client_supp_plan_id == pagesUploadedPlanId )]
%var mbsUploadPlan = existingPlans[?( $.client_supp_plan_id == mbsUploadedPlanId )]
%var gbsUploadPlan = existingPlans[?( $.client_supp_plan_id == gbsUploadedPlanId )]
%var pagesHostedPlan = existingPlans[?( $.client_supp_plan_id == pagesHostedPlanId )]
%var mbsHostedPlan = existingPlans[?( $.client_supp_plan_id == mbsHostedPlanId )]
%var gbsHostedPlan = existingPlans[?( $.client_supp_plan_id == gbsHostedPlanId )]

%var specialMediaPlan = existingPlans[?( $.client_supp_plan_id == SpecialMediaPlanId )].client_supp_plan_instance_id[0]
%var specialMediaHostedPlan = existingPlans[?( $.client_supp_plan_id == SpecialMediaHostedPlanId )].client_supp_plan_instance_id[0]


%var billingEffectiveDate = asDate(flowVars.theProject.billingEffectiveDate)
%var activeDate = asDate(flowVars.theProject.activeDate)

%function activeLabelMapping(setProjectStatus) null when ( sizeOf (ariaAcctDetails.activeLabel default '') ) > 0 otherwise
 'Launched' when setProjectStatus == Active and (billingEffectiveDate == null or activeDate < billingEffectiveDate) otherwise 'Effective'

%var ActiveLabel = 'ACTIVE_LABEL'
%var CloseDate = 'CLOSE_DATE'
%var HibernateDate = 'HIBERNATE_DATE'
%var SuspendedDate = 'SUSPENDED_DATE'
%var PendingCloseDate = 'PENDING_CLOSE_DATE'

%var currentActiveLabelParsed = (ariaAcctDetails.*supp_field[?( $.supp_field_name == ActiveLabel )])
//%var currentActiveLabelHasValue = false when currentActiveLabelParsed == null otherwise true
%var currentActiveLabelHasValue = currentActiveLabelParsed[0].supp_field_value?

%var currentHibernateDateParsed = (ariaAcctDetails.*supp_field[?( $.supp_field_name == HibernateDate )])
%var currentHibernateDateHasValue = currentHibernateDateParsed[0].supp_field_value?

%var currentSuspendDateParsed = (ariaAcctDetails.*supp_field[?( $.supp_field_name == SuspendedDate )])
%var currentSuspendDateHasValue = currentSuspendDateParsed[0].supp_field_value?

%var currentCloseDateParsed = (ariaAcctDetails.*supp_field[?( $.supp_field_name == CloseDate )])
%var currentCloseDateHasValue = currentCloseDateParsed[0].supp_field_value?

%var currentPendingCloseDateParsed = (ariaAcctDetails.*supp_field[?( $.supp_field_name == PendingCloseDate )])
%var currentPendingCloseDateHasValue = currentPendingCloseDateParsed[0].supp_field_value?

%var currentHistoricalEffectiveDateParsed = (ariaAcctDetails.master_plans_info.*mp_plan_inst_fields[?( $.plan_instance_field_name == HistoricalEffectiveDate )])
%var currentHistoricalEffectiveDateValue = currentHistoricalEffectiveDateParsed[0].plan_instance_field_value

%var currentHostingLabelParsed = (ariaAcctDetails.*supp_field[?( $.supp_field_name == HostingLabel )])
%var currentHostingLabelHasValue = currentPendingCloseDateParsed[0].supp_field_value?

%var salesReps = flowVars.salesReps map ( $.name default '' ++ '|' ++ $.employeeNumber default '' ++ '|' ++ $.isPrimary default '' ++ '|' ++ $.splitPercentage default '') joinBy ';'

%var primarySalesRep = flowVars.salesReps[0] when (sizeOf flowVars.salesReps) == 1 otherwise ( flowVars.salesReps filter ( $.isPrimary as :boolean ) )[0]

%var specialMediaRateAssigned =
 flowVars.theProject.hibernationRateSM when projectStatus == Hibernation otherwise
 flowVars.theProject.continuationRateSM when inContinuation otherwise
 flowVars.theProject.specialMediaRate
%var invoiceTemplateMapping = lookup('lookupFromInvoiceTemplateMapping_Flow', { country: flowVars.theCompany.billingAddress.country, businessUnit: flowVars.theProject.businessUnit })
---
{
  soap#Envelope: {
    soap#Header: {},
    soap#Body: {
      lit#update_acct_plan_multi_m: {
        client_no: p('aria.client_no'),
        auth_key: p('aria.auth_key'),
        acct_no: flowVars.ariaValues.ariaAcct,
        do_write: true,

        assignment_directive: 3,


        plan_updates: {
          plan_updates_row: {
            plan_directive: 1,
            new_client_plan_id: "DataSite",
            (plan_status_cd: masterPlanStatus) when masterPlanStatus != null,
            billing_group_idx: 1,
            dunning_group_no: ariaAcctDetails.master_plans_info.dunning_group_no,
            plan_instance_idx: 1,
            po_num: flowVars.theCompany.customerOrderNumber,
            plan_instance_field_update: {} ++
              createPlanInstanceField("BILL_TO_ADDRESS_IDS", flowVars.theCompany.billingAddress.oracleSiteId) ++
              createPlanInstanceField("BUSINESS_UNIT", flowVars.theProject.businessUnit) ++
              createPlanInstanceField("CONTINUATION_DATE", flowVars.theProject.continuationDate) ++
              createPlanInstanceField("CONTINUATION_RATE", flowVars.theProject.continuationRate) ++
              createPlanInstanceField("CONTINUATION_RATE_SM", flowVars.theProject.continuationRateSM) ++

              createPlanInstanceField("CONTRACT_CUSTOMER",           contractCustomer1) ++
              createPlanInstanceField("CONTRACT_CUSTOMER_ADDRESS",   contractCustomer2) ++
              createPlanInstanceField("CONTRACT_CUSTOMER_CONTACT",   contractCustomer3) ++
              createPlanInstanceField("CONTRACT_TERM", floor flowVars.theProject.contractTerm) ++
              createPlanInstanceField("COUNTRY_OF_ISSUER", flowVars.theProject.countryOfIssuer) ++
              createPlanInstanceField("CURRENT_ENTITLEMENT", projEntitlement()) ++
              createPlanInstanceField("EFFECTIVE_DATE", flowVars.theProject.billingEffectiveDate) ++
              createPlanInstanceField("HIBERNATION_RATE", flowVars.theProject.hibernationRate) ++
              createPlanInstanceField("HIBERNATION_RATE_SM", flowVars.theProject.hibernationRateSM) ++
              createPlanInstanceField("MEDIA_USED", "0") ++
              createPlanInstanceField("MEDIA_INCLUDED", flowVars.theProject.closureMediaInclude) ++
              createPlanInstanceField("OPERATING_UNIT_NAME", flowVars.theProject.operatingUnitId default '' ++ '-' ++ flowVars.theProject.operatingUnitName default '') ++
              createPlanInstanceField("PRIMARY_REP_ID", null when primarySalesRep == null otherwise primarySalesRep.employeeNumber) ++
              createPlanInstanceField("PRIMARY_REP_NAME", null when primarySalesRep == null otherwise primarySalesRep.name) ++
              createPlanInstanceField("PRIMARY_SERVICE_SITE", flowVars.theProject.primaryServiceSite) ++
              createPlanInstanceField("PROCESSED_FOR_CONTRACT_MINIMUM", 0 when hasMinimumFee otherwise 1) ++
              createPlanInstanceField("PRODUCT_TYPE", 'Datasite-' ++ flowVars.theProject.productType default 'NOT PROVIDED') ++
              createPlanInstanceField("PROJECT_CREATION_DATE", flowVars.theProject.createdAt as :date as :string {format: 'yyyy-MM-dd'}) ++
              createPlanInstanceField("PROJECT_PHASE", projectAndPlanStatusMapping().projectStatus) ++
              createPlanInstanceField("REVENUE_SITE", trimToThree(flowVars.theProject.revenueSite)) ++
              createPlanInstanceField("SALESFORCE_PROJECT_ID", flowVars.theProject.projectSfdcId) ++
              createPlanInstanceField("SALESFORCE_PROJECT_NAME", flowVars.theProject.name) ++
              createPlanInstanceField("SALESREP_SPLIT_AMOUNT", salesReps) 
          },
          (plan_updates_row: {
            new_client_plan_id: "Special_Media",
            plan_directive: 1 when specialMediaPlan == null otherwise 1,
            (plan_status_cd: suppPlanStatus) when suppPlanStatus != null,
            custom_rates: {
              custom_rates_row: {
                custom_rate_client_service_id: specialMediaPlanName,
                custom_rate_seq_no: 1,
                custom_rate_from_unit: 1,
                custom_rate_per_unit: specialMediaRateAssigned
              }
            },
            plan_service_updates: {
              plan_service_updates_row: {
              	client_service_id: specialMediaPlanName,
              	client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
              }
            },
            usage_accumulation_reset_months: 99,
            parent_plan_instance_idx: 1
          }) when billedByUploaded,
          (plan_updates_row: {
            new_client_plan_id: "Special_Media",
            plan_directive: 1 when specialMediaPlan == null otherwise 1,
            (plan_status_cd: suppPlanStatus) when suppPlanStatus != null,
            parent_plan_instance_idx: 1,
            plan_service_updates: {
              plan_service_updates_row: {
              	client_service_id: specialMediaPlanName,
              	client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
              }
            }
          }) when not billedByUploaded and specialMediaPlan != null,

          (plan_updates_row: {
            new_client_plan_id: "Special_Media_Hosted",
            plan_directive: 1 when specialMediaHostedPlan == null otherwise 1,
            (plan_status_cd: suppPlanStatus) when suppPlanStatus != null,
            custom_rates: {
              custom_rates_row: {
                custom_rate_client_service_id: specialMediaHostedPlanName,
                custom_rate_seq_no: 1,
                custom_rate_from_unit: 1,
                custom_rate_per_unit: specialMediaRateAssigned
              }
            },
            plan_service_updates: {
              plan_service_updates_row: {
              	client_service_id: specialMediaHostedPlanName,
              	client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
              }
            },
            usage_accumulation_reset_months: 99,
            parent_plan_instance_idx: 1,
            (plan_instance_field_update: createPlanInstanceFieldCheckExisting(HostingLabel, hostingLabelValue, currentHostingLabelHasValue) ) when billedByHosted
          }) when billedByHosted,
          (plan_updates_row: {
            new_client_plan_id: "Special_Media_Hosted",
            plan_directive: 1 when specialMediaHostedPlan == null otherwise 1,
            (plan_status_cd: suppPlanStatus) when suppPlanStatus != null,
            parent_plan_instance_idx: 1,
            plan_service_updates: {
              plan_service_updates_row: {
              	client_service_id: specialMediaHostedPlanName,
              	client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
              }
            }
          }) when not billedByHosted and specialMediaHostedPlan != null,

          plan_updates_row: {
            new_client_plan_id: "Pages_Uploaded",
            plan_directive: 1,
            (plan_status_cd: suppPlanStatus) when suppPlanStatus != null,
            parent_plan_instance_idx: 1,
            (custom_rates: customRatesForUploaded) when billedByPagesUploaded,
            plan_service_updates: {
              plan_service_updates_row: {
              	client_service_id: "PgUploaded",
              	client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
              },
             plan_service_updates_row: {
              	client_service_id: "PgMinimumFee",
              	client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
              } 
            }
          },
          plan_updates_row: {
            new_client_plan_id: "MBs_Uploaded",
            plan_directive: 1,
            (plan_status_cd: suppPlanStatus) when suppPlanStatus != null,
            parent_plan_instance_idx: 1,
            (custom_rates: customRatesForUploaded) when billedByMBsUploaded,
            plan_service_updates: {
              plan_service_updates_row: {
              	client_service_id: "MBUploaded",
              	client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
              },
             plan_service_updates_row: {
              	client_service_id: "MBMinimumFee",
              	client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
              } 
            }
          },
          plan_updates_row: {
            new_client_plan_id: "GBs_Uploaded",
            plan_directive: 1,
            (plan_status_cd: suppPlanStatus) when suppPlanStatus != null,
            parent_plan_instance_idx: 1,
            (custom_rates: customRatesForUploaded) when billedByGBsUploaded,
            plan_service_updates: {
              plan_service_updates_row: {
              	client_service_id: "GBUploaded",
              	client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
              }
            },
             plan_service_updates_row: {
              	client_service_id: "GBMinimumFee",
              	client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
              } 
          },
          plan_updates_row: {
            new_client_plan_id: "Pages_Hosted",
            plan_directive: 1,
            (plan_status_cd: suppPlanStatus) when suppPlanStatus != null,
            (custom_rates: customRatesForHosted) when billedByPagesHosted,
            plan_service_updates: {
              plan_service_updates_row: {
              	client_service_id: "PgHosted",
              	client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
              }
            },
            parent_plan_instance_idx: 1,
            (plan_instance_field_update: createPlanInstanceFieldCheckExisting(HostingLabel, hostingLabelValue, currentHostingLabelHasValue) ) when billedByHosted
          },
          plan_updates_row: {
            new_client_plan_id: "MBs_Hosted",
            plan_directive: 1,
            (plan_status_cd: suppPlanStatus) when suppPlanStatus != null,
            parent_plan_instance_idx: 1,
            (custom_rates: customRatesForHosted) when billedByMBsHosted,
            plan_service_updates: {
              plan_service_updates_row: {
              	client_service_id: "MBHosted",
              	client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
              }
            },
            (plan_instance_field_update: createPlanInstanceFieldCheckExisting(HostingLabel, hostingLabelValue, currentHostingLabelHasValue) ) when billedByHosted
          },
          plan_updates_row: {
            new_client_plan_id: "GBs_Hosted",
            plan_directive: 1,
            (plan_status_cd: suppPlanStatus) when suppPlanStatus != null,
            parent_plan_instance_idx: 1,
            (custom_rates: customRatesForHosted) when billedByGBsHosted,
            plan_service_updates: {
              plan_service_updates_row: {
              	client_service_id: "GBHosted",
              	client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
              }
            },
            (plan_instance_field_update: createPlanInstanceFieldCheckExisting(HostingLabel, hostingLabelValue, currentHostingLabelHasValue) ) when billedByHosted
          }          
          },
          acct_billing_groups: {
          acct_billing_groups_row: {
              billing_group_directive: 1,                
              billing_group_name: flowVars.theProject.projectSfdcId,
              billing_group_idx: 1,
              statement_template: invoiceTemplateMapping.statementTemplate, //112,
              credit_note_template: invoiceTemplateMapping.creditNoteTemplate,
              credit_memo_template: invoiceTemplateMapping.creditMemoTemplate,
              rebill_template: invoiceTemplateMapping.rebillTemplate,
              stmt_contact_idx: 1
              }
            },
            contacts: {
              contacts_row: {
                contact_idx: 1,
                first_name: flowVars.theCompany.firstName,
                last_name: flowVars.theCompany.lastName,
                company_name: flowVars.theCompany.billingCompany.name,
                address1: flowVars.theCompany.billingAddress.address1,
                address2: flowVars.theCompany.billingAddress.address2,
                address3: flowVars.theCompany.billingAddress.address3,
                city: flowVars.theCompany.billingAddress.city,
                locality: flowVars.theCompany.billingAddress.locality,
                state_prov: flowVars.theCompany.billingAddress.stateProvince,
                country: flowVars.theCompany.billingAddress.country,
                postal_cd: flowVars.theCompany.billingAddress.postalCode,
                phone: flowVars.theCompany.phone,
                email: flowVars.theCompany.email
              }
            }
        }
    }
  }
}
