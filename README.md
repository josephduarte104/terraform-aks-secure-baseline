# Terraform AKS Module for Blue/Green Nodepools

This repo has 2 relevant branches

master - blue green deployments can be managed at a lower level where system and
user pools are defined seperately.

bluegreen - deployments are managed as "blue" or "green".  Blue contains 2 node
pools (system and user) and Green contains 2 node pools (system and user).
There is also a drain flag that will taint and cordon nodes.
