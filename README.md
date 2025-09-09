# 🏠 Smart Utility Metering Contract

A Clarity smart contract for tracking and paying water/electricity usage based on IoT oracle readings.

## 🚀 Features

- **⚡ Multi-Utility Support**: Track both water and electricity consumption
- **🔗 Oracle Integration**: IoT devices can submit meter readings
- **💰 Automated Billing**: Calculate bills based on consumption and rates
- **💳 Prepaid System**: Users deposit funds and pay bills automatically
- **🛡️ Secure**: Oracle-based readings prevent tampering
- **📊 Usage Tracking**: Historical consumption data storage

## 🏗️ Contract Structure

### Core Functions

#### 👤 User Management
- `register-user`: Register with water and electricity meter IDs
- `deposit-funds`: Add funds to account balance
- `get-user-info`: View account information

#### 📊 Oracle Operations
- `submit-reading`: Submit meter readings (oracle-only)
- `process-bill`: Calculate and create bills (oracle-only)
- `add-oracle`/`remove-oracle`: Manage authorized oracles

#### 💸 Billing & Payments
- `pay-bill`: Pay pending utility bills
- `get-pending-bill`: View current bill
- `calculate-water-bill`/`calculate-electricity-bill`: Calculate costs

#### ⚙️ Administrative
- `set-water-rate`/`set-electricity-rate`: Update utility rates
- `emergency-withdraw`: Admin emergency fund withdrawal

## 🔧 Usage Instructions

### 1. Setup
Deploy the contract and set initial rates:
```clarity
(contract-call? .smart-utility-metering set-water-rate u50)
(contract-call? .smart-utility-metering set-electricity-rate u75)
```

### 2. Register Oracle
```clarity
(contract-call? .smart-utility-metering add-oracle 'SP1ORACLE...)
```

### 3. User Registration
```clarity
(contract-call? .smart-utility-metering register-user "WATER-001" "ELEC-001")
```

### 4. Fund Account
```clarity
(contract-call? .smart-utility-metering deposit-funds u10000)
```

### 5. Submit Readings (Oracle)
```clarity
(contract-call? .smart-utility-metering submit-reading "WATER-001" u1500 "water")
(contract-call? .smart-utility-metering submit-reading "ELEC-001" u2000 "electricity")
```

### 6. Process Bill (Oracle)
```clarity
(contract-call? .smart-utility-metering process-bill 'SP1USER... u1500 u2000)
```

### 7. Pay Bill
```clarity
(contract-call? .smart-utility-metering pay-bill)
```

## 💡 Example Workflow

1. **🏠 User registers** with meter IDs
2. **💰 User deposits** funds into account
3. **📡 IoT oracles submit** meter readings
4. **🧮 System calculates** usage and bills
5. **💳 User pays** bill from account balance
6. **📈 System tracks** historical consumption

## 📋 Data Structures

- **Users**: Balance, meter IDs, consumption history
- **Oracles**: Authorized reading submitters
- **Meter Readings**: Timestamped utility readings
- **Pending Bills**: Unpaid utility charges

## 🔒 Security Features

- Owner-only admin functions
- Oracle-only reading submissions
- Balance validation before payments
- Duplicate registration prevention

## 🛠️ Development

Built with Clarinet framework for Stacks blockchain.

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy
```

## 📊 Rate Structure

- **Water**: Rate per unit (default: 50 microSTX)
- **Electricity**: Rate per unit (default: 75 microSTX)
- **Billing Cycle**: 144 blocks (~24 hours)

## 🎯 Use Cases

- **🏘️ Smart Cities**: Municipal utility management
- **🏭 Industrial**: Factory consumption tracking
- **🏠 Residential**: Home utility monitoring
- **💼 Commercial**: Business utility billing

---

*Built with ❤️ for the Stacks ecosystem*
