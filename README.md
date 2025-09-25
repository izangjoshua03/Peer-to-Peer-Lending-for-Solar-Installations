# ☀️ Peer-to-Peer Lending for Solar Installations

A decentralized lending platform built on the Stacks blockchain that enables peer-to-peer financing for solar panel installations, making clean energy accessible to low-income households through community-driven microfinance.

## 🌟 Overview

This smart contract creates a marketplace where households can request loans for solar installations while lenders can pool funds to support clean energy adoption. The system uses smart contracts to manage repayments, track energy generation, and handle collateral through partial ownership of solar panel systems.

## 🎯 Key Features

- **📋 Loan Applications**: Households can create detailed loan requests with solar installation specifications
- **💰 Community Funding**: Multiple lenders can contribute to fund individual loans
- **🔒 Smart Collateral**: Loans are collateralized with partial ownership rights of solar panels
- **📊 Energy Tracking**: Real-time monitoring of solar energy generation through installer reports
- **⚡ Automated Payments**: Monthly payment processing with automatic distribution to lenders
- **🛡️ Default Management**: Automated default detection and collateral management
- **💎 Platform Fees**: Configurable platform fees for sustainability

## 🏗️ Core Functions

### For Borrowers
- `create-loan-request`: Submit a loan application with solar installation details
- `make-payment`: Make monthly loan payments

### For Lenders
- `fund-loan`: Contribute STX tokens to fund loans partially or fully
- View loan details and track investments through read-only functions

### For Installers
- `report-energy-generation`: Submit monthly energy generation reports

### For Platform Admin
- `verify-installation`: Verify completed solar installations
- `initiate-default-process`: Handle loan defaults
- `set-platform-fee`: Adjust platform fee rates

## 💡 How It Works

1. **Application**: Households apply for solar loans with installation details
2. **Funding**: Community lenders pool STX to fund approved applications
3. **Installation**: Solar panels are installed with verified specifications
4. **Monitoring**: Energy generation is tracked and reported monthly
5. **Repayment**: Borrowers make monthly payments distributed to lenders
6. **Completion**: Successful repayment transfers full ownership to borrower

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing
- Basic understanding of Clarity smart contracts

### Installation
1. Clone this repository
2. Navigate to the project directory
3. Run `clarinet check` to verify contract compilation
4. Use `clarinet console` to interact with the contract

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet publish
```

## 📊 Contract Data Structures

The contract manages several key data maps:
- **loans**: Complete loan information and status
- **solar-installations**: Technical specifications and verification status  
- **lender-contributions**: Individual lender investments per loan
- **usage-reports**: Monthly energy generation tracking
- **borrower-loans**: Borrower loan history
- **lender-portfolio**: Lender investment portfolios

## 🔒 Security Features

- Owner-only administrative functions
- Input validation for all public functions
- Automatic payment distribution
- Default detection based on payment history
- Collateral management through ownership rights

## 🌱 Environmental Impact

This platform democratizes access to clean energy by:
- Reducing barriers to solar adoption for low-income households
- Creating sustainable financing through community support  
- Tracking and verifying actual environmental benefits
- Supporting the transition away from fossil fuels

## 📈 Economic Model

- **Platform Fee**: 2.5% of monthly payments (configurable)
- **Interest Rates**: Set by borrowers, determined by market
- **Collateral**: Partial panel ownership (up to 100%)
- **Default Threshold**: 90 days without payment (configurable)

## 🤝 Contributing

We welcome contributions to improve this platform! Please feel free to submit issues, feature requests, or pull requests.

## 📄 License

This project is open source. Please review the license file for more details.

## 🎉 Join the Clean Energy Revolution

Help make solar energy accessible to everyone while earning returns on your investment. Together, we can build a more sustainable future through decentralized finance!
