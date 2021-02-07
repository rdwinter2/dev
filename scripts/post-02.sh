#!/usr/bin/env bash

istioctl x precheck

istioctl install --set profile=demo -y

