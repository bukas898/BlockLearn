# BlockLearn

BlockLearn is a decentralized educational platform built on the Stacks blockchain that enables educators to create, monetize, and manage online courses while providing students with verifiable course enrollments and secure access to educational content.

## Features

- **Course Management**
  - Educators can register courses with customizable pricing
  - Support for both one-time purchases and subscription-based models
  - Secure content access through blockchain verification
  - Custom syllabus URI support for course materials

- **Revenue Management**
  - Automated revenue sharing between educators and platform
  - Transparent commission structure
  - Direct educator earnings withdrawal
  - Real-time balance tracking

- **Enrollment System**
  - Secure student enrollment verification
  - Subscription period management
  - Enrollment status tracking
  - Cancellation support

- **Administrative Controls**
  - Flexible platform commission adjustment
  - Secure administrative transfer capability
  - Built-in access control mechanisms

## Smart Contract Functions

### For Educators

- `register-course`: Register a new course with pricing and enrollment parameters
- `withdraw-educator-earnings`: Withdraw accumulated teaching revenue
- `get-educator-current-balance`: Check current earnings balance

### For Students

- `enroll-in-course`: Enroll in a specific course
- `cancel-enrollment`: Cancel an active course enrollment
- `verify-course-access`: Verify access rights to course content

### For Administrators

- `update-platform-commission`: Update the platform's commission rate
- `transfer-platform-administration`: Transfer administrative rights

## Error Codes

| Code | Description |
|------|-------------|
| u1 | Unauthorized Access |
| u2 | Invalid Pricing Parameters |
| u3 | Duplicate Enrollment |
| u4 | Course Not Found |
| u5 | Insufficient STX Balance |
| u6 | Enrollment Expired |
| u7 | Invalid Enrollment Duration |
| u8 | Invalid Course ID |
| u9 | Invalid Syllabus URI |
| u10 | Invalid Administrator |

## Technical Details

- Built on Stacks blockchain
- Written in Clarity smart contract language
- Uses STX for payments and transactions
- Implements secure principal-based authentication

## Getting Started

1. Deploy the smart contract to the Stacks blockchain
2. Set up the initial platform administrator
3. Configure the platform commission rate
4. Begin registering courses and managing enrollments

## Security Considerations

- All financial transactions are secured by blockchain technology
- Access control is managed through principal-based authentication
- Revenue distribution is automated and transparent
- Administrative functions are protected by authorization checks

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
