# Clarity Payroll System Smart Contract

A comprehensive payroll management system built on Clarity for the Stacks blockchain.

## Overview

This smart contract provides a complete payroll management solution for organizations, allowing them to:
- Manage employee records (add, update, deactivate, reactivate)
- Process payroll for both salaried and hourly employees
- Handle tax withholdings and benefits deductions
- Track payment history
- Record hours worked for hourly employees

## Features

- **Dual Payment Support**: Supports both salaried and hourly employees
- **Benefits Management**: Configurable benefits rate per employee
- **Tax Withholding**: Automated tax calculations based on configurable rates
- **Payment History**: Complete record of all payments processed
- **Employee Management**: Add, update, deactivate, and reactivate employees
- **Hours Tracking**: Record and retrieve hours worked for hourly employees
- **Scheduled Payments**: Set and retrieve the next payday
- **Customizable Pay Periods**: Adjust pay period length as needed

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Employee not found |
| u102 | Insufficient funds |
| u103 | Employee already exists |
| u104 | Invalid amount |
| u105 | Invalid date |
| u106 | Payment already processed |

## Data Structures

### Employees Map
Stores employee information including:
- Address (principal)
- Name
- Salary (for salaried employees)
- Hourly rate (for hourly employees)
- Employment type flag (hourly or salaried)
- Benefits rate (in basis points - 1/100 of 1%)
- Tax rate (in basis points - 1/100 of 1%)
- Last paid timestamp
- Active status

### Payroll History Map
Records all payment transactions with:
- Gross amount
- Tax amount
- Benefits amount
- Net amount
- Timestamp
- Payment status

### Hours Worked Map
Tracks hours worked for hourly employees by pay period.

## Public Functions

### Employee Management
- `add-employee`: Add a new employee to the system
- `update-employee`: Update an existing employee's information
- `deactivate-employee`: Mark an employee as inactive
- `reactivate-employee`: Restore an inactive employee to active status

### Payroll Processing
- `record-hours`: Record hours worked for hourly employees
- `process-payment`: Process payment for a single employee
- `run-payroll`: Process payroll for all active employees
- `set-pay-period-length`: Update the pay period length
- `initialize`: Set up the contract with the first payday

### Financial Functions
- `add-funds`: Add funds to the contract
- `withdraw-funds`: Withdraw funds from the contract (owner only)

## Read-Only Functions

- `get-employee`: Retrieve employee details
- `get-payment-history`: View payment history for an employee
- `get-hours`: Get recorded hours for an employee
- `get-balance`: Check contract balance
- `get-next-payday`: Get the next scheduled payday
- `get-pay-period-length`: Get current pay period length
- `employee-exists`: Check if an employee is in the system
- `calculate-payment`: Calculate payment amounts for an employee
- `list-active-employees`: List all active employees

## Usage Examples

### Adding a Salaried Employee
```clarity
(contract-call? .payroll-system add-employee 
  "EMP001" 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
  "John Doe" 
  u5000000000 
  u0 
  false 
  u750   ;; 7.5% benefits rate
  u2000  ;; 20% tax rate
)
```

### Adding an Hourly Employee
```clarity
(contract-call? .payroll-system add-employee 
  "EMP002" 
  'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG 
  "Jane Smith" 
  u0 
  u25000000 
  true 
  u500   ;; 5% benefits rate
  u1500  ;; 15% tax rate
)
```

### Recording Hours
```clarity
(contract-call? .payroll-system record-hours 
  "EMP002" 
  u1654041600  ;; Period end timestamp
  u80          ;; 80 hours worked
)
```

### Processing Payment
```clarity
(contract-call? .payroll-system process-payment 
  "EMP001" 
  u1654041600  ;; Period end timestamp
)
```

## Implementation Notes

- All currency amounts are in the smallest unit (e.g., microSTX if working with STX)
- Rates are in basis points (1 basis point = 0.01%)
- The contract does not directly transfer funds to employees, it only tracks amounts
- Due to Clarity limitations on loops, the `run-payroll` function requires an off-chain component to call `process-payment` for each active employee

## Security Considerations

- Only the contract owner can add/update employees and process payments
- The contract implements checks to prevent double payments
- Funds must be added to the contract before processing payroll