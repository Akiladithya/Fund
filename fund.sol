// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GovernmentFundFlow is Ownable, Pausable, ReentrancyGuard {
    struct Bill {
        uint id;
        address department;
        uint amount;
        bool approved;
        bool paid;
    }

    uint public billCounter;
    uint public maxBillAmount = 1000 ether;
    mapping(uint => Bill) public bills;
    mapping(address => bool) public authorizedDepartments;
    mapping(address => uint) public departmentBalances;

    modifier onlyDepartment() {
        require(authorizedDepartments[msg.sender], "Not an authorized department");
        _;
    }

    event BillSubmitted(uint indexed id, address indexed department, uint amount);
    event BillApproved(uint indexed id);
    event BillPaid(uint indexed id, address indexed department, uint amount);
    event DepartmentAuthorized(address indexed department);
    event DepartmentRemoved(address indexed department);
    event MaxBillAmountChanged(uint newMax);

    constructor() Ownable(msg.sender) {}

    function authorizeDepartment(address department) external onlyOwner {
        authorizedDepartments[department] = true;
        emit DepartmentAuthorized(department);
    }

    function removeDepartment(address department) external onlyOwner {
        require(department != owner(), "Owner cannot be removed as a department");
        authorizedDepartments[department] = false;
        emit DepartmentRemoved(department);
    }

    function submitBill(uint amount) external onlyDepartment whenNotPaused {
        require(amount > 0 && amount <= maxBillAmount, "Invalid bill amount");

        unchecked { billCounter++; }
        bills[billCounter] = Bill(billCounter, msg.sender, amount, false, false);
        emit BillSubmitted(billCounter, msg.sender, amount);
    }

    function approveBill(uint billId) external onlyOwner whenNotPaused {
        Bill storage bill = bills[billId];
        require(!bill.approved, "Already approved");
        require(!bill.paid, "Already paid");
        bill.approved = true;
        emit BillApproved(billId);
    }

    function payBill(uint billId) external nonReentrant whenNotPaused {
        Bill storage bill = bills[billId];
        require(bill.approved, "Bill not approved");
        require(!bill.paid, "Bill already paid");
        require(address(this).balance >= bill.amount, "Insufficient contract balance");

        bill.paid = true;
        departmentBalances[bill.department] += bill.amount;
        payable(bill.department).transfer(bill.amount);

        emit BillPaid(billId, bill.department, bill.amount);
    }

    function depositFunds() external payable onlyOwner whenNotPaused {}

    function setMaxBillAmount(uint _max) external onlyOwner {
        maxBillAmount = _max;
        emit MaxBillAmountChanged(_max);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    receive() external payable {}
}
