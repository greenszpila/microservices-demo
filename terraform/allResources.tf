terraform {
  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
    }
  }
}

provider "newrelic" {
  api_key = var.NEW_RELIC_API_KEY
  account_id = var.NEW_RELIC_ACCOUNT_ID
  region = var.NEW_RELIC_REGION
}

# Create Workload

resource "newrelic_workload" "ms-demo-workload" {
    name = "Online-Boutique Store Workload"
    account_id = var.NEW_RELIC_ACCOUNT_ID
    entity_search_query {
        query = "(name like '%store-%' AND type = 'APPLICATION') OR type = 'KUBERNETES_POD' OR type ='CONTAINER' OR type = 'KUBERNETESCLUSTER'" 
    }

    scope_account_ids =  [var.NEW_RELIC_ACCOUNT_ID]
}

# Create Service Levels for 2 services based on Latency & Error Rate

data "newrelic_entity" "ms-demo-productcatalogservice-app" {
  name = "store-productcatalogservice"
  domain = "APM"
  type = "APPLICATION"
}

data "newrelic_entity" "ms-demo-frontend-app" {
  name = "store-frontend"
  domain = "APM"
  type = "APPLICATION"
}

resource "newrelic_service_level" "ms-demo-productcatalogservice-latency-sl" {
  guid = "${data.newrelic_entity.ms-demo-productcatalogservice-app.guid}"
    name = "Online-Boutique ProductCatalogue Latency SL"
    description = "Proportion of requests that are served faster than a threshold."

    events {
        account_id = var.NEW_RELIC_ACCOUNT_ID
        valid_events {
            from = "Transaction"
            where = "appName = 'store-productcatalogservice' AND (transactionType='Web')"
        }
        good_events {
            from = "Transaction"
            where = "appName = 'store-productcatalogservice' AND (transactionType= 'Web') AND duration < 0.05"
        }
    }

    objective {
        target = 99.00
        time_window {
            rolling {
                count = 7
                unit = "DAY"
            }
        }
    }
}

resource "newrelic_service_level" "ms-demo-frontend-latency-sl" {
  guid = "${data.newrelic_entity.ms-demo-frontend-app.guid}"
    name = "Online-Boutique FrontEnd Latency SL"
    description = "Proportion of requests that are served faster than a threshold."

    events {
        account_id = var.NEW_RELIC_ACCOUNT_ID
        valid_events {
            from = "Transaction"
            where = "appName = 'store-frontend' AND (transactionType='Web')"
        }
        good_events {
            from = "Transaction"
            where = "appName = 'store-frontend' AND (transactionType= 'Web') AND duration < 0.05"
        }
    }

    objective {
        target = 99.00
        time_window {
            rolling {
                count = 7
                unit = "DAY"
            }
        }
    }
}

resource "newrelic_service_level" "ms-demo-frontend-error-sl" {
  guid = "${data.newrelic_entity.ms-demo-frontend-app.guid}"
    name = "Online-Boutique Frontend Error Rate SL"
    description = "Proportion of requests that are failing"

    events {
        account_id = var.NEW_RELIC_ACCOUNT_ID
        valid_events {
            from = "Transaction"
            where = "appName = 'store-frontend'"
        }
        bad_events {
            from = "TransactionError"
            where = "appName = 'store-frontend' AND error.expected IS FALSE"
        }
    }

    objective {
        target = 99.00
        time_window {
            rolling {
                count = 7
                unit = "DAY"
            }
        }
    }
}

resource "newrelic_service_level" "ms-demo-productcatalogservice-error-sl" {
  guid = "${data.newrelic_entity.ms-demo-productcatalogservice-app.guid}"
    name = "Online-Boutique ProductCatalogue Error Rate SL"
    description = "Proportion of requests that are failing"

    events {
        account_id = var.NEW_RELIC_ACCOUNT_ID
        valid_events {
            from = "Transaction"
            where = "appName = 'store-productcatalogservice'"
        }
        bad_events {
            from = "TransactionError"
            where = "appName = 'store-productcatalogservice' AND error.expected IS FALSE"
        }
    }

    objective {
        target = 99.00
        time_window {
            rolling {
                count = 7
                unit = "DAY"
            }
        }
    }
}

# Create Alerts based on APM Response Time & Kubernetes Cluster status



resource "newrelic_alert_policy" "ms-demo-obs-alert-policy" {
  name = "Online Boutique - Latency & K8S Stability Alerts"
}

resource "newrelic_nrql_alert_condition" "ms-demo-latency-condition" {
  account_id                     = var.NEW_RELIC_ACCOUNT_ID
  policy_id                      = newrelic_alert_policy.ms-demo-obs-alert-policy.id
  type                           = "static"
  name                           = "High Latency"
  description                    = "Alert when transactions are taking too long"
  enabled                        = true
  violation_time_limit_seconds   = 3600
  fill_option                    = "static"
  fill_value                     = 1.0
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  expiration_duration            = 120
  open_violation_on_expiration   = true
  close_violations_on_expiration = true
  slide_by                       = 30

  nrql {
    query = "SELECT average(duration) FROM Transaction where (appName = 'store-productcatalogservice' OR appName = 'store-frontend') FACET appName"
  }

  critical {
    operator              = "above"
    threshold             = 1
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }

  warning {
    operator              = "above"
    threshold             = 0.5
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}


resource "newrelic_nrql_alert_condition" "ms-demo-k8s-stability-condition" {
  account_id                     = var.NEW_RELIC_ACCOUNT_ID
  policy_id                      = newrelic_alert_policy.ms-demo-obs-alert-policy.id
  type                           = "static"
  name                           = "Cluster Stability"
  description                    = "Alert when PODs desired are higher than PODs ready"
  enabled                        = true
  violation_time_limit_seconds   = 3600
  fill_option                    = "static"
  fill_value                     = 1.0
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  expiration_duration            = 120
  open_violation_on_expiration   = true
  close_violations_on_expiration = true
  slide_by                       = 30

  nrql {
    query = "FROM K8sReplicasetSample select latest(podsDesired) - latest(podsReady) facet replicasetName, deploymentName"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 120
    threshold_occurrences = "ALL"
  }
}