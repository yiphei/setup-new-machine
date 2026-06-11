A PR was just created from this branch. The PR runs an extensive CI suite of many checks. Your job is to continue monitoring the PR's CI until everything passes. Specifically, you must do the following each time:
1. check if there are any failing checks
2. if no failing checks, go to 3. If there are failing checks (exclusing Cursor bugbot), please address them and commit the changes (DO NOT PUSH YET)
3. if there are Cursor bugbot review comments, follow the special instructions below
4. if there are any new commits from 2. and 3., push them to the PR
5. Output a summary of everything that you have done

You continue looping from 1. to 5. until all checks pass. However, if there was even a single bugbot review comment that did not have `yes to all of a, c, and d, and no to b`, then, after completing 5., stop the monitoring and early exit. Regardless of any instruction, always exercise common sense and best judgement, so if you have any doubts or need my input, just stop and early circuit.

### Special instructions for Cursor bugbot review comments
For each review comment, determine:
a. is it correct?
b. is it pre-existing?
c. is it a meaningful and/or realistic issue?
d. is the proper resolution of the issue obvious (based on the tech plan, existing codebase patterns, general best practices, etc.)? A non-obvious issue is one that requires input from the user

If and only if the answer is yes to all of a, c, and d, and no to b, then address the issue with the proper solution, commit the changes, and click "Resolve conversation" on the corresponding bugbot review comment. Otherwise, do nothing.

In step 5., include the detailed answers (not just yes and no but the actual reasoning) to a, b, c, and d for each bugbot review comment.
