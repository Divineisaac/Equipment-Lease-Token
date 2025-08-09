# Equipment Lease Tokenization Smart Contract

A comprehensive Clarity smart contract for tokenizing equipment leases on the Stacks blockchain. This contract enables equipment owners to create lease agreements, collect payments, and manage equipment maintenance while providing lessees with tradeable NFT tokens representing their lease rights.

## Features

### Core Functionality
- **Equipment Registration**: Register equipment with detailed metadata including name, description, value, category, and condition
- **Lease Creation**: Create lease agreements with customizable terms including duration, monthly payments, and security deposits
- **Payment Processing**: Handle lease payments with automatic platform fee collection
- **Lease Tokenization**: Issue NFT tokens representing lease rights that can be transferred
- **Maintenance Tracking**: Record and track equipment maintenance history
- **Payment History**: Comprehensive payment tracking and history

### Equipment Categories
- Construction
- Medical
- Industrial
- Technology
- Automotive

### Equipment Conditions
- New
- Excellent
- Good
- Fair

## Contract Structure

### Data Maps
- `equipment-registry`: Stores equipment details and metadata
- `lease-agreements`: Manages lease terms and status
- `payment-history`: Tracks all payments made
- `maintenance-records`: Records equipment maintenance activities

### NFT Token
- `lease-token`: Non-fungible tokens representing lease rights

## Functions

### Equipment Management

#### `register-equipment`
Register new equipment for leasing.
```clarity
(register-equipment 
  (name (string-ascii 256))
  (description (string-ascii 512))
  (value uint)
  (category (string-ascii 64))
  (condition (string-ascii 32)))
```

#### `update-equipment-availability`
Update equipment availability status (owner only).
```clarity
(update-equipment-availability (equipment-id uint) (available bool))
```

### Lease Management

#### `create-lease`
Create a new lease agreement and mint lease token.
```clarity
(create-lease 
  (equipment-id uint)
  (lessee principal)
  (duration-blocks uint)
  (monthly-payment uint)
  (security-deposit uint))
```

#### `make-payment`
Process lease payments (monthly, deposit, penalty, maintenance).
```clarity
(make-payment (lease-id uint) (payment-type (string-ascii 32)))
```

#### `terminate-lease`
Terminate an active lease agreement.
```clarity
(terminate-lease (lease-id uint))
```

#### `transfer-lease-token`
Transfer lease token to new owner.
```clarity
(transfer-lease-token (lease-id uint) (new-owner principal))
```

### Maintenance Management

#### `record-maintenance`
Record equipment maintenance activities.
```clarity
(record-maintenance 
  (equipment-id uint)
  (maintenance-type (string-ascii 64))
  (cost uint)
  (description (string-ascii 256)))
```

### Read-Only Functions

#### Query Functions
- `get-equipment (equipment-id uint)`: Get equipment details
- `get-lease (lease-id uint)`: Get lease agreement details
- `get-payment (lease-id uint) (payment-id uint)`: Get payment record
- `get-maintenance-record (equipment-id uint) (record-id uint)`: Get maintenance record
- `is-lease-overdue (lease-id uint)`: Check if lease payment is overdue
- `needs-maintenance (equipment-id uint)`: Check if equipment needs maintenance
- `get-lease-token-owner (lease-id uint)`: Get current lease token owner
- `get-equipment-count ()`: Get total number of registered equipment
- `get-lease-count ()`: Get total number of leases created

## Payment Types

- `PAYMENT-MONTHLY`: Regular monthly lease payment
- `PAYMENT-DEPOSIT`: Security deposit payment
- `PAYMENT-PENALTY`: Penalty payment for late fees
- `PAYMENT-MAINTENANCE`: Maintenance cost payment

## Administrative Functions

### `update-contract-owner`
Transfer contract ownership (owner only).

### `update-platform-fee`
Update platform fee percentage (max 10%, owner only).

### `toggle-contract-pause`
Pause/unpause contract operations (owner only).

### `emergency-withdraw`
Emergency withdrawal of contract funds (owner only, requires contract to be paused).

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-NOT-AUTHORIZED | User not authorized for action |
| 101 | ERR-NOT-FOUND | Resource not found |
| 102 | ERR-ALREADY-EXISTS | Resource already exists |
| 103 | ERR-INVALID-AMOUNT | Invalid amount specified |
| 104 | ERR-INSUFFICIENT-BALANCE | Insufficient balance |
| 105 | ERR-LEASE-EXPIRED | Lease has expired |
| 106 | ERR-LEASE-NOT-ACTIVE | Lease is not active |
| 107 | ERR-INVALID-DURATION | Invalid lease duration |
| 108 | ERR-EQUIPMENT-NOT-AVAILABLE | Equipment not available |
| 109 | ERR-PAYMENT-FAILED | Payment transaction failed |
| 110 | ERR-INVALID-PRINCIPAL | Invalid principal address |
| 111 | ERR-MAINTENANCE-REQUIRED | Equipment maintenance required |

## Usage Examples

### Registering Equipment
```clarity
(contract-call? .equipment-lease register-equipment 
  "Excavator CAT 320" 
  "Heavy-duty construction excavator in excellent condition" 
  u500000 
  "construction" 
  "excellent")
```

### Creating a Lease
```clarity
(contract-call? .equipment-lease create-lease 
  u1 
  'SP1EXAMPLE... 
  u43200  ;; ~300 days
  u5000   ;; Monthly payment in microSTX
  u10000) ;; Security deposit
```

### Making a Payment
```clarity
(contract-call? .equipment-lease make-payment u1 "monthly")
```

## Block Time Calculations

The contract uses Stacks block heights for timing:
- 1 block ≈ 10 minutes (Stacks average)
- 1 day ≈ 144 blocks
- 1 month (30 days) ≈ 4,320 blocks
- 2 months (60 days) ≈ 8,640 blocks

## Platform Fees

Default platform fee is 2.5% (250 basis points) of each payment, automatically collected and transferred to the contract owner.

## Security Features

- Owner-only administrative functions
- Contract pause mechanism for emergencies
- Input validation for all parameters
- Authorization checks for all operations
- Emergency withdrawal capability (when paused)

## Deployment

1. Deploy the contract to Stacks blockchain
2. Set appropriate platform fees
3. Begin registering equipment
4. Create lease agreements as needed