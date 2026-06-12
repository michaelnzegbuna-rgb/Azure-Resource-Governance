# Assignment Screenshots

To complete your assignment submission, you must take and place two screenshots in this folder:

1.  **`deny-error.png`**
    *   **Description**: A screenshot of the "Deny" policy violation error message received when attempting to deploy a resource without mandatory tags.
    *   **How to capture**:
        *   If using the **Azure Portal**: Try creating a storage account or other resource and leave tags blank. Click *Review + Create*. You will see a red validation banner. Click on it to show the error details pointing to the policy `Enforce Mandatory Tags and Allowed Values` and capture the screen.
        *   If using **PowerShell or Azure CLI**: Run the test script `deploy-test-resources.ps1` or `deploy-test-resources.sh`. Capture a screenshot of your terminal window showing the red/error output with the `RequestDisallowedByPolicy` error code.

2.  **`compliance-dashboard.png`**
    *   **Description**: A screenshot of the Azure Policy Compliance Dashboard showing compliant resources.
    *   **How to capture**:
        *   In the Azure Portal search bar, search for **Policy**.
        *   Go to **Compliance** under the Authoring section on the left-side menu.
        *   Locate the assignment `Enforce Mandatory Tags and Allowed Values Assignment`.
        *   Click on it to view the compliance details and overall resource health.
        *   Capture a screenshot showing the compliance percentage and resource list.
