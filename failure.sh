#!/bin/bash

# Get the user's choice
echo "Choose a failure scenario:"
echo "1.Failure1: delete checkout pod/svc: Users are unable to make purchases"
echo "2.Fix Failure 1"
echo "3.Failure2: reccommendation svc: set env RANDOM_ERROR=0.10 :number of clicks to recommended products has dropped"
echo "4.Fix Failure 2"
echo "5.Failure3: productcatalog svc: set env EXTRA_LATENCY="5.5s": slow web "
echo "6.Fix Failure 3"
echo "7.Failure4: store-cart-svc: loadgen redis: cart svc addItem KT error budged dropping"
echo "8.Fix Failure 4"
read choice

# Handle the user's choice
case $choice in
1)
  echo "Failure1 F1 Deleting checkoutservice deployment..."
  kubectl delete deploy checkoutservice -n store
  ;;
2)
  echo "Fix F1  Reapplying checkoutservice manifest "
  kubectl -n store apply -f ./kubernetes-manifests/chEckoutservice.yaml
  ;;
3)
  echo "Apply F2: setting RANDOM_ERROR..."
  kubectl -n store set env deployment/recommendationservice RANDOM_ERROR=0.10
  ;;
4)
  echo "Fix F2: Clearing RANDOM_ERROR "
  kubectl -n store set env deployment/recommendationservice RANDOM_ERROR-
  ;;
5)
  echo "Apply F3: Setting EXTRA_LATENCY..."
  kubectl -n store set env deployment/productcatalogservice EXTRA_LATENCY="5.5s"
  ;;
6)
  echo "Fix F3 clearing EXTRA_LATENCY..."
  kubectl -n store set env deployment/productcatalogservice EXTRA_LATENCY-
  ;;
7)
  echo "Apply F4: Deploying loadgeneratorredis..."
  kubectl apply -f ./kubernetes-manifests/loadgeneratorredis.yaml -n store
  ;;
8)
  echo "Fix F4: Deleting loadgeneratorredis deployment..."
  kubectl delete deploy loadgeneratorredis -n store
  ;;
esac
