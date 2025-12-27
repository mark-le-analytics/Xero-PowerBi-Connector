# 🔌 Xero API Custom Connector for Power BI
### 🏆 Strategic Project – Melbourne Victory FC (2025)

![Power BI](https://img.shields.io/badge/Power_BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)
![Xero](https://img.shields.io/badge/Xero-13B5EA?style=for-the-badge&logo=xero&logoColor=white)
![OAuth 2.0](https://img.shields.io/badge/Auth-OAuth_2.0_PKCE-green?style=flat-square)

A production-grade **Power Query (M)** custom connector (`.mez`) designed to automate financial data extraction from the Xero Accounting API directly into Power BI.

Developed during my tenure at **Melbourne Victory FC**, this project automated the ingestion of historical financial data (**2018–2025**), eliminating manual CSV exports and significantly reducing reporting effort and operational risk.





## 🎯 Project Impact
* **Automation:** Replaced manual Xero exports with a direct API-to-Power BI data pipeline.
* **Scalability:** Engineered to handle **400MB+ datasets** (Journals and Invoices) without memory crashes or infinite loops.
* **Accuracy:** Removed human error in data preparation through deterministic Power Query (M) transformations.



## 🧠 Technical Features
* **OAuth 2.0 with PKCE:** Secure authentication flow with automated token refresh, fully compatible with Power BI Desktop and Service (via Gateway).
* **Hybrid Pagination Logic:** Dynamically switches between **page-based** (Invoices, Contacts) and **offset-based** (Journals) pagination strategies based on specific endpoint behavior.
* **Performance Optimisation:** Server-side `where` clause filtering reduces API payload size and improves refresh performance by limiting data to the 2018–2030 range.
* **Sanitised Data Handling:** Automatic conversion of Xero .NET JSON date formats (`/Date(milliseconds)/`) into Power BI standard `DateTime` values.



## 📦 Supported Endpoints & Pagination Strategy
| Endpoint | Strategy | Design Choice |
| :--- | :--- | :--- |
| **Invoices / Contacts** | **Page-based** | Iterates until no records are returned. |
| **Journals** | **Offset-based** | Increments by `pageSize` (100) with `maxPages` safety limits. |
| **Manual Journals** | **Single request** | Explicitly bypasses pagination for non-paginated endpoints. |



## 🛠 Setup & Installation

### 1. Security Configuration
Power BI restricts custom connectors by default.
1. Open **Power BI Desktop**.
2. Go to **File → Options and Settings → Options → Security**.
3. Under **Data Extensions**, select **“Allow any extension to load without validation”**.

### 2. Xero App Setup
1. Log in to the [Xero Developer Portal](https://developer.xero.com/).
2. Create a **Mobile or Desktop** application.
3. Set the Redirect URI to: `https://oauth.powerbi.com/views/oauthredirect.html`
4. Copy your **Client ID**.

### 3. Build the Connector
1. Open the project in VS Code with the **Power Query SDK**.
2. Paste your Client ID into the `client_id` variable in `XeroConnector.pq`.
3. Build the project to generate the `.mez` file.
4. Copy the `.mez` file to: `Documents\Power BI Desktop\Custom Connectors`.



## ☁️ Cloud Deployment & Scheduled Refresh

To enable scheduled refresh on **PowerBI.com**:

1.  **On-Premises Data Gateway:** Install the Gateway (Standard mode recommended).
2.  **Connector Visibility:** Ensure the Gateway is configured to "Use custom connectors" and points to the folder containing your `.mez` file.

3.  **Cloud Credentials:** In the Semantic Model settings on Power BI Service, edit credentials and authenticate using **OAuth** to sign in to your Xero organization.



## 👤 Author

**Mark Le** *Data Analyst – Strategic Projects* Specialising in Data Analytics, Business Analytics, and BI Engineering.



## ⚠️ Disclaimer

> [!IMPORTANT]
> This repository is a **sanitised version** of the connector used at Melbourne Victory FC.
> 
> * No Client Secrets, Tenant IDs, or access tokens are included.
> * No production financial data is contained within this repository.
> * Users must provide their own Xero Developer credentials to use this connector.
