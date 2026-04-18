# Bank Customer Profitability & Growth Strategy
**Executive‑Focused Financial Analysis (SQL + Power BI)**

## What This Project Is About (Why It Exists)

Bank growth is not driven by transaction volume alone — it is driven by **profitable customers, effective product focus, and disciplined resource allocation**.

This project analyzes **five years of customer banking activity** for a **single bank operating five branches**, with the objective of helping executives answer one core question:

> **Where should the bank focus its capital, products, and customer engagement efforts to grow sustainably?**

The analysis prioritizes **decision‑making**, not technical complexity.  
Executives can extract value from this project **without reading a single SQL query**.

## If You Only Have 5 Minutes

1. Read the **Executive Summary** below  
2. Review **Key Decisions Enabled**  
3. Jump to **Recommendations**  
4. (Optional) Open Power BI dashboards for visual validation

## Executive Summary

This project evaluates customer and branch profitability using **fees paid**, **loan exposure**, **deposit behavior**, and **interest margins**, while distinguishing between the bank’s **assets (loans)** and **liabilities (deposits)**.

### Core Findings

- **Profitability is concentrated**: a minority of customers generate a majority of total value
- **High balances do not always equal high profitability**
- Customers holding **multiple products** consistently outperform single‑product customers
- Certain branches behave primarily as **deposit collectors**, while others act as **credit engines**
- Digitally active customers represent a **high‑ROI cross‑sell opportunity**

### Why This Matters

- Blanket marketing strategies waste capital
- Branches should not be evaluated using identical KPIs
- Growth comes from **deepening relationships**, not just acquiring customers

### Executive Implication

Leadership can **increase revenue without increasing risk** by reallocating marketing effort, sharpening product focus, and targeting specific customer segments with proven profitability patterns.

## Key Decisions Enabled

This analysis supports leadership in making the following decisions:

- ✅ Which customers to prioritize for **cross‑selling and upselling**
- ✅ Which products should be **focus products** moving forward
- ✅ How to allocate **marketing and relationship‑management resources**
- ✅ How to differentiate **branch‑level strategies**
- ✅ How to distinguish **high‑balance vs high‑value customers**

## Background

Traditional bank reporting focuses heavily on **balances and transaction counts**, often overlooking **true customer value**.

This project reframes customer analysis around:
- **Fee contribution**
- **Loan relationships**
- **Interest margin**
- **Product depth**
- **Behavioral engagement**

By linking customer behavior directly to profitability, the analysis aligns financial data with **strategic decision‑making**.

## Data Structure (Conceptual Overview)

The dataset simulates a production‑grade core banking system using a relational SQL schema.

### Entities Included

- **Customers**
  - Demographics
  - Employment and salary indicators
- **Accounts**
  - Transactional accounts
  - Savings and deposit accounts
  - Loan accounts
- **Transactions**
  - Fees
  - Transfers
  - Bill payments
- **Loans**
  - Balances
  - Repayment patterns
- **Branches**
  - Customer ownership
  - Product concentration

### Time Horizon

- **Five-year window**
- Enables trend analysis, behavioral shifts, and long‑term value assessment

## Profitability & KPI Framework

Customer profitability is evaluated on an **aggregated basis**, segmented by:

- Branch
- Product
- Demographics

### Core Metrics

- Total fees paid
- Loan balances
- Interest income
- Interest paid on deposits
- Asset vs liability composition
- Account count per customer
- Channel usage (digital vs traditional)
- Salaried vs non‑salaried customers

This framework allows leadership to see **both value creation and embedded risk**.

## Insights Deep Dive (Optional)

### Customer Value Drivers

- Customers with **multiple products** consistently generate higher lifetime value
- Loan + deposit customers outperform pure deposit holders
- Transaction frequency contributes more to profitability than balance size alone

### Asset–Liability Balance

- Some branches accumulate deposits without proportional lending activity
- Others produce strong loan growth with weaker liability backing

📌 This imbalance has implications for:
- Liquidity planning
- Capital efficiency
- Branch‑specific targets

### Cross‑Sell & Upsell Signals

Strong indicators of untapped growth include:
- Salaried customers without credit products
- High-balance customers with only one product
- Digitally engaged customers with minimal product penetration

These customers represent **growth potential rather than credit risk**.

## Recommendations

### 1. Precision Customer Targeting

**Who**: Retail Banking & Marketing  
**Action**: Target customers with stable income and multiple accounts for loan and premium product offers  
**Outcome**: Higher revenue per customer with controlled risk exposure

### 2. Branch-Specific Strategy

**Who**: Executive & Branch Leadership  
**Action**: Customize branch KPIs based on asset–liability mix and customer composition  
**Outcome**: Improved capital deployment and realistic performance evaluation

### 3. Product Focus Optimization

**Who**: Product & Strategy Teams  
**Action**: Prioritize high-margin, low-operational-cost products for growth campaigns  
**Outcome**: Sustainable revenue growth without proportional cost increases

## Tools & Technology

- **SQLite** — analytical SQL queries
- **Power BI** — executive dashboards and visual storytelling
- **Python (Faker)** — synthetic data generation

## How to Use This Repository

- **Executives**  
  Read this README for strategic insight. Dashboards are supplementary.

- **Analysts**  
  Review SQL scripts to understand methodology or extend the analysis.

- **Recruiters / Reviewers**  
  This project demonstrates end‑to‑end analytical ownership, business thinking, and executive communication.

## Design Principles

- **Clarity over Complexity**
- **Function over Beauty**
- **Insight before technique**
- **Depth is optional, value is immediate**

---

*This project uses simulated data and does not represent real customer information.*
``
