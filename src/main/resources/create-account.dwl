%dw 1.0
%output application/xml
%namespace lit urn:client:api:wsdl:document/literal_wrapped:vers:11.0:aria_complete_m_api
%namespace soap http://schemas.xmlsoap.org/soap/envelope/

%var projectStatus = flowVars.theProject.projectStatus

%function createField(key, value) {} when value == null or value == "" otherwise plan_instance_fields_info_row: { field_name: key, field_value: value }
%function createSuppField(key, value) {} when value == null or value == "" otherwise supp_field_row: { supp_field_name: key, supp_field_value: value }
%function basedOnLegalName(value) "AAHCM5122B" when value == "010" otherwise "AAHCM0547Q" when value == "071" otherwise null
//%function findSize(value) 2 when sizeOf(payload.message) > 3 otherwise sizeOf(payload.message) - 1
//This is ugly, I can't find a better way, looks like some up and coming versions can do this much easier like [0 to findTheIndex(value)]
//where findTheIndex is a function to figure out what size we want to use

%function trimToThree(value) value[0..2] when (sizeOf value) > 2 otherwise value[0..1] when (sizeOf value) == 2 otherwise value[0] when (sizeOf value) == 1 otherwise null

%function splitUpLegalName() flowVars.theProject.legalEntity splitBy "-"
%var legalEntityId = trim ( splitUpLegalName()[0] default '999' )
%var legalEntityName = trim ( splitUpLegalName()[1] default 'NOT PROVIDED' )

%var invoiceMapping = lookup('lookupFromInvoiceMappingFlow', { currency: flowVars.theProject.currency, legalEntity: legalEntityId, operatingUnitId: flowVars.theProject.operatingUnitId })
%var invoiceTemplateMapping = lookup('lookupFromInvoiceTemplateMapping_Flow', { country: flowVars.theCompany.billingAddress.country, businessUnit: flowVars.theProject.businessUnit })

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

%function projectAndPlanStatusMapping()
 { masterPlanStatus: 61, suppPlanStatus: 32, projectStatus: 'Preparation' } when projectStatus == 'Build Period' otherwise
 { masterPlanStatus: 1, suppPlanStatus: 1, projectStatus: projectStatus } when projectStatus == 'Active' otherwise
 { masterPlanStatus: 2, suppPlanStatus: 2, projectStatus: 'Pending Close' } when projectStatus == 'Closure Request' otherwise
 { masterPlanStatus: -3, suppPlanStatus: -3, projectStatus: projectStatus } when projectStatus == 'Closed' otherwise
 { masterPlanStatus: 1, suppPlanStatus: 1, projectStatus: projectStatus } when projectStatus == 'Hibernation' otherwise
 { masterPlanStatus: -1, suppPlanStatus: -1, projectStatus: projectStatus } when projectStatus == 'Suspended' otherwise
 { masterPlanStatus: 99, suppPlanStatus: 99, projectStatus: 'NOT KNOWN' }

%var contractCustomer = (flowVars.theProject.contractCustomer default '')
%var contractCustomerArray = contractCustomer splitBy ','
%var contractCustomerSize = sizeOf ( contractCustomerArray )
%var contractCustomer1 = '' when contractCustomerSize < 1 otherwise trim contractCustomerArray[0]
%var contractCustomer2 = '' when contractCustomerSize < 2 otherwise trim contractCustomerArray[1]
%var contractCustomer3 = '' when contractCustomerSize < 3 otherwise trim contractCustomerArray[2]


%var billedByPagesUploaded = flowVars.theProject.unitOfMeasure == 'Page'
%var billedByMBsUploaded = flowVars.theProject.unitOfMeasure == 'MB'
%var billedByGBsUploaded = flowVars.theProject.unitOfMeasure == 'GB'

%var clientPlanName = 'Pages_Uploaded' when billedByPagesUploaded otherwise 'MBs_Uploaded' when billedByMBsUploaded otherwise 'GBs_Uploaded' when billedByGBsUploaded otherwise null
%var clientServiceName = 'PgUploaded' when billedByPagesUploaded otherwise 'MBUploaded' when billedByMBsUploaded otherwise 'GBUploaded' when billedByGBsUploaded otherwise null
%var clientServiceNameMinimumFee = 'PgMinimumFee' when billedByPagesUploaded otherwise 'MBMinimumFee' when billedByMBsUploaded otherwise 'GBMinimumFee' when billedByGBsUploaded otherwise null
%var customRates = {
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

%var salesReps = flowVars.salesReps map ( $.name default '' ++ "|" ++ $.employeeNumber default '' ++ "|" ++ $.isPrimary default '' ++ "|" ++ $.splitPercentage default '') joinBy ";"
%var primarySalesRep = flowVars.salesReps[0] when (sizeOf flowVars.salesReps) == 1 otherwise ( flowVars.salesReps filter ( $.isPrimary as :boolean ) )[0]

%function cdataField(field) null when field == null otherwise field as :cdata
---
{
  soap#Envelope: {
    soap#Header: {},
    soap#Body: {
      lit#create_acct_complete_m: {
        client_no: p('aria.client_no'),
        auth_key: p('aria.auth_key'),
        do_write: true,
        acct: {
          acct_row: {
            company_name: flowVars.theCompany.billingCompany.name,
            acct_currency: flowVars.theProject.currency,
            billing_group: {
              billing_group_row: {
                billing_group_name: ( (flowVars.theCompany.billingCompany.oracleAccountId default '') ++ '-' ++ (flowVars.theCompany.billingAddress.oracleSiteId default '') ++ '-' ++ (flowVars.theProject.currency default '') ),
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
            },
            dunning_group: {
              dunning_group_row: {
                dunning_group_name: "DEFAULT",
                dunning_group_idx: 1
              }
            },
            invoicing_option: 4,
            client_legal_entity_id: legalEntityId,
            master_plans_detail: {
              master_plans_detail_row: {
                client_plan_id: "DataSite",
                plan_instance_status: 32,
                billing_group_idx: 1, //Needs to match up with billing_group_idx
                dunning_group_idx: 1, //Needs to match up with the dunning_group_idx
                master_plan_services: {
                  master_plan_services_row: {
                    client_svc_location_id: flowVars.theProject.revenueSite
                  }
                },
                po_num: flowVars.theCompany.customerOrderNumber,
                plan_instance_fields_info: {} ++
                  createField("BILL_TO_ADDRESS_IDS",            flowVars.theCompany.billingAddress.oracleSiteId) ++
                  createField("BUSINESS_UNIT",                  flowVars.theProject.businessUnit) ++
                  createField("CONTINUATION_RATE",              flowVars.theProject.continuationRate) ++
                  createField("CONTINUATION_RATE_SM",           flowVars.theProject.continuationRateSM) ++
                  createField("CONTRACT_CUSTOMER",              contractCustomer1) ++
                  createField("CONTRACT_CUSTOMER_ADDRESS",      contractCustomer2) ++
                  createField("CONTRACT_CUSTOMER_CONTACT",      contractCustomer3) ++
                  createField("CONTRACT_TERM",                  floor flowVars.theProject.contractTerm) ++
                  createField("COUNTRY_OF_ISSUER",              flowVars.theProject.countryOfIssuer) ++
                  createField("CURRENT_ENTITLEMENT",            projEntitlement()) ++
                  createField("EFFECTIVE_DATE",                 flowVars.theProject.billingEffectiveDate) ++
                  createField("HIBERNATION_RATE",               flowVars.theProject.hibernationRate) ++
                  createField("HIBERNATION_RATE_SM",            flowVars.theProject.hibernationRateSM) ++
                  createField("MEDIA_USED",                     "0") ++
                  createField("MEDIA_INCLUDED",                 flowVars.theProject.closureMediaInclude) ++
                  createField("OPERATING_UNIT_NAME",            flowVars.theProject.operatingUnitId default '' ++ '-' ++ flowVars.theProject.operatingUnitName default '') ++
                  createField("PRIMARY_REP_ID",                 primarySalesRep.employeeNumber) ++
                  createField("PRIMARY_REP_NAME",               primarySalesRep.name) ++
                  createField("PRIMARY_SERVICE_SITE",           flowVars.theProject.primaryServiceSite) ++
                  createField("PROCESSED_FOR_CONTRACT_MINIMUM", 0 when hasMinimumFee otherwise 1) ++
                  createField("PRODUCT_TYPE",                   'Datasite-' ++ flowVars.theProject.productType default 'NOT PROVIDED') ++
                  createField("PROJECT_CREATION_DATE",          flowVars.theProject.createdAt as :date as :string {format: 'yyyy-MM-dd'}) ++
                  createField("PROJECT_PHASE",                  projectAndPlanStatusMapping().projectStatus) ++
                  createField("REVENUE_SITE",                   trimToThree(flowVars.theProject.revenueSite)) ++
                  createField("SALESFORCE_PROJECT_ID",          flowVars.theProject.projectSfdcId) ++
                  createField("SALESFORCE_PROJECT_NAME",        flowVars.theProject.name) ++
                  createField("SALESREP_SPLIT_AMOUNT",          salesReps) ++
                  createField("SPLIT_BILLING_ACCOUNTS",         " ") ++
                  createField("SPLIT_BILLING_INV_TEXT",         " "),

                supp_plan: {
                  supp_plan_row: {
                    client_plan_id: "Special_Media",
                    supp_plan_services: {
                      supp_plan_services_row: {
                        client_service_id: "SMUploaded",
                        client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
                      }
                    },
                    custom_rates: {
                      custom_rates_row: {
                        custom_rate_client_service_id: 'SMUploaded',
                        custom_rate_seq_no: 1,
                        custom_rate_from_unit: 1,
                        custom_rate_per_unit: flowVars.theProject.specialMediaRate
                      }
                    },
                    usage_accumulation_reset_months: 99
                  },
                  supp_plan_row: {
                    client_plan_id: 'Pages_Uploaded',
                    supp_plan_services: {
                      supp_plan_services_row: {
                        client_service_id: "PgUploaded",
                        client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
                      },
                      supp_plan_services_row: {
                        client_service_id: "PgMinimumFee",
                        client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
                      }
                    },
                    (custom_rates: customRates) when billedByPagesUploaded,
                    usage_accumulation_reset_months: 99
                  },
                  supp_plan_row: {
                    client_plan_id: 'MBs_Uploaded',
                    supp_plan_services: {
                      supp_plan_services_row: {
                        client_service_id: "MBUploaded",
                        client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
                      },
                      supp_plan_services_row: {
                        client_service_id: "MBMinimumFee",
                        client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
                      }
                    },
                    (custom_rates: customRates) when billedByMBsUploaded,
                    usage_accumulation_reset_months: 99
                  },
                  supp_plan_row: {
                    client_plan_id: 'GBs_Uploaded',
                    supp_plan_services: {
                      supp_plan_services_row: {
                        client_service_id: "GBUploaded",
                        client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
                      },
                      supp_plan_services_row: {
                        client_service_id: "GBMinimumFee",
                        client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
                      }
                    },
                    (custom_rates: customRates) when billedByGBsUploaded,
                    usage_accumulation_reset_months: 99
                  },
                  supp_plan_row: {
                    client_plan_id: 'Pages_Hosted',
                    supp_plan_services: {
                      supp_plan_services_row: {
                        client_service_id: "PgHosted",
                        client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
                      }
                    },
                    usage_accumulation_reset_months: 99
                  },
                  supp_plan_row: {
                    client_plan_id: 'MBs_Hosted',
                    supp_plan_services: {
                      supp_plan_services_row: {
                        client_service_id: "MBHosted",
                        client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
                      }
                    },
                    usage_accumulation_reset_months: 99
                  },
                  supp_plan_row: {
                    client_plan_id: 'GBs_Hosted',
                    supp_plan_services: {
                      supp_plan_services_row: {
                        client_service_id: "GBHosted",
                        client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
                      }
                    },
                    usage_accumulation_reset_months: 99
                  },
                  supp_plan_row: {
                    client_plan_id: 'Special_Media_Hosted',
                    supp_plan_services: {
                      supp_plan_services_row: {
                        client_service_id: "SMHosted",
                        client_svc_location_id: trimToThree(flowVars.theProject.revenueSite)
                      }
                    },
                    usage_accumulation_reset_months: 99
                  }
                }
              }
            },
            notify_method: 10,
            retroactive_start_date: flowVars.theProject.retroStartDate,
            supp_field: {} ++
              createSuppField("INVOICE_TERM_VERBIAGE", cdataField(invoiceMapping.verbiage)) ++
              createSuppField("INVOICE_FOOTER_NOTE",   cdataField(invoiceMapping.footerNote)) ++
              createSuppField("INVOICE_FOOTER_LEFT",   cdataField(invoiceMapping.footerLeft)) ++
              createSuppField("INVOICE_FOOTER_RIGHT",  cdataField(invoiceMapping.footerRight)) ++
              createSuppField("INVOICE_HEADER_LEFT",   cdataField(invoiceMapping.headerLeft)) ++
              createSuppField("INVOICE_HEADER_RIGHT",  cdataField(invoiceMapping.headerRight)) ++

              createSuppField("LEGAL_ENTITY",          legalEntityId) ++
              createSuppField("LEGAL_ENTITY_NAME",     legalEntityName) ++
              createSuppField("ORACLE_ID",             flowVars.theCompany.billingAddress.oracleSiteId) ++
              createSuppField("PAN_TAX_NO",            basedOnLegalName(legalNameId) when flowVars.theCompany.billingcountry == 'IN' otherwise null) ++

              createSuppField("SFDC_ID",               flowVars.theCompany.billingAddress.sfdcId) ++
              createSuppField("VAT_REGISTRATION_NO",   flowVars.theCompany.billingCompany.vatRegistration) ++
              createSuppField("VAT_COUNTRY_CODE",      null when flowVars.theCompany.billingCompany.vatRegistration == null otherwise flowVars.theCompany.billingAddress.country)
          }
        }
      }
    }
  }
}
