#!/usr/bin/env bash
kubectl delete -n mm101-tutorial pod/mm101-tutorial-matchfunction
kubectl delete -n mm101-tutorial pod/mm101-tutorial-director
kubectl delete -n mm101-tutorial pod/mm101-tutorial-frontend
