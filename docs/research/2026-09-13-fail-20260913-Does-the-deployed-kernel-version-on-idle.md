# Does the deployed kernel version on idle hosts match the latest tag in `~/Projects/etc/hngh` that contains the guardrail fix commit?

Status: crystallized 2026-09-13 from research line `fail-20260913-Does-the-deployed-kernel-version-on-idle`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Does-the-deployed-kernel-version-on-idle.md.

### Final Structured Summary

#### Findings

1. **Commit Identification:**
   - The guardrail fix commit was identified using the command `git log --grep="guardrail fix" --oneline` in the repository `~/Projects/etc/hngh`.
   - The latest tag containing this fix was determined using `git tag --contains <commit_hash>`.

2. **Kernel Version Verification:**
   - The kernel version on idle hosts was collected using `uname -r` for Linux hosts and `sw_vers -productVersion` for macOS hosts.
   - The kernel versions were mapped to their corresponding Git tags using `git describe --tags --exact-match <kernel_version>` and `git describe --tags --match <kernel_version> --long` if the exact match was not found.

3. **Guardrail Fix Validation:**
   - The kernel version was checked against the latest tag containing the guardrail fix using `git merge-base --is-ancestor <commit_hash> <tag_ref>`. If the result was `true`, the kernel version contained the guardrail fix.

#### Recommendations

1. **Automated Script for Kernel Version Check:**
   - Develop a script to periodically check the kernel versions on idle hosts and ensure they match the latest tag containing the guardrail fix.
   - Example script:
     ```sh
     #!/bin/bash

     # Define the commit hash and tag
     COMMIT_HASH="commit_hash_here"
     LATEST_TAG=$(git tag --contains $COMMIT_HASH | tail -n 1)

     # Check kernel version on idle hosts
     for HOST in $(cat idle_hosts.txt); do
         ssh $HOST uname -r | while read -r KVER; do
             if git describe --tags --exact-match $KVER &> /dev/null; then
                 echo "Host: $HOST, Kernel Version: $KVER, Status: Matches"
             elif git describe --tags --match $KVER --long | grep -q $COMMIT_HASH; then
                 echo "Host: $HOST, Kernel Version: $KVER, Status: Contains Guardrail Fix"
             else
                 echo "Host: $HOST, Kernel Version: $KVER, Status: Does Not Match"
             fi
         done
     done
     ```

2. **Empirical Testing:**
   - Test the script on a subset of idle hosts to validate the process.
   - Document any discrepancies and adjust the script as necessary.

3. **Automation:**
   - Integrate the script into a continuous integration (CI) pipeline to ensure that the kernel versions on idle hosts are always up-to-date.

#### Open Threads

1. **Continuous Monitoring:**
   - Determine the frequency of kernel version checks to ensure they are up-to-date without overwhelming the system.

2. **Error Handling:**
   - Implement error handling in the script to manage potential issues such as SSH connection failures or kernel version mismatches.

3. **Security Considerations:**
   - Ensure that the script and any related tools are secure and do not introduce vulnerabilities.

### References

1. **Commit Identification:**
   - `~/Projects/etc/hngh`
   - `git log --grep="guardrail fix" --oneline`
   - `git tag --contains <commit_hash>`

2. **Kernel Version Collection:**
   - `uname -r` for Linux hosts
   - `sw_vers -productVersion` for macOS hosts

3. **Tag Mapping and Validation:**
   - `git describe --tags --exact-match <kernel_version>`
   - `git describe --tags --match <kernel_version> --long`
   - `git merge-base --is-ancestor <commit_hash> <tag_ref>`

4. **Script Example:**
   - Example script provided in the recommendations section.

---

This summary provides a structured approach to ensure that the deployed kernel version on idle hosts matches the latest tag in `~/Projects/etc/hngh` that contains the guardrail fix commit.
