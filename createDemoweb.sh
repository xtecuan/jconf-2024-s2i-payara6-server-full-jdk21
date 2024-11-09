#!/bin/bash

oc process template/payara6-basic-s2i -n xtecuan-dev --param-file=payara6-xtecuan-dev.env > demoweb-xtecuan-dev.json