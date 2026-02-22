package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides functions for managing accounts, transactions and users
type SmartContract struct {
	contractapi.Contract
}

// Account represents a bank account on the blockchain
type Account struct {
	ID        string `json:"id"`
	Bank      string `json:"bank"`
	Currency  string `json:"currency"`
	Type      string `json:"type"`
	Available string `json:"available"` // string pour gros montants
	Blocked   bool   `json:"blocked"`
}

// Transaction represents a token transfer or mint
type Transaction struct {
	ID        string `json:"id"`
	From      string `json:"from"`
	To        string `json:"to"`
	Amount    string `json:"amount"`
	Block     string `json:"block"`
	Timestamp string `json:"timestamp"`
}

// User represents a blockchain user
type User struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Email  string `json:"email"`
	Role   string `json:"role"`
	Active bool   `json:"active"`
}

// DashboardStats holds aggregated statistics
type DashboardStats struct {
	Blocks             uint64  `json:"blocks"`
	TotalTransactions  uint64  `json:"totalTransactions"`
	ActivePeers        uint64  `json:"activePeers"`
	ActiveOrderers     uint64  `json:"activeOrderers"`
	NetworkPerformance uint64  `json:"networkPerformance"`
	AvgTPS             float64 `json:"avgTPS"`
	BreakTPS           float64 `json:"breakTPS"`
	ActiveUsers        uint64  `json:"activeUsers"`
}

// ===================================================================
// INIT LEDGER
// ===================================================================
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	accounts := []Account{
		{ID: "ACC001", Bank: "BNK001", Currency: "MAD", Type: "Checking", Available: "950"},
		{ID: "ACC002", Bank: "BNK002", Currency: "MAD", Type: "Savings", Available: "1980"},
		{ID: "ACC003", Bank: "BNK001", Currency: "MAD", Type: "Business", Available: "4750"},
		{ID: "ACC004", Bank: "BNK004", Currency: "MAD", Type: "Checking", Available: "1400"},
		{ID: "ACC005", Bank: "BNK003", Currency: "MAD", Type: "Savings", Available: "2900"},
		{ID: "ACC006", Bank: "BNK004", Currency: "MAD", Type: "Business", Available: "750"},
	}
	for _, acc := range accounts {
		accJSON, _ := json.Marshal(acc)
		ctx.GetStub().PutState("account_"+acc.ID, accJSON)
	}

	users := []User{
		{ID: "USR001", Name: "John Doe", Email: "john@example.com", Role: "Admin", Active: true},
		{ID: "USR002", Name: "Jane Smith", Email: "jane@example.com", Role: "User", Active: false},
		{ID: "USR003", Name: "Fatima Bouarfa", Email: "fatima@mailex.com", Role: "User", Active: true},
		{ID: "USR004", Name: "Youssef Ndiaye", Email: "you@nd.com", Role: "Auditor", Active: true},
	}
	for _, user := range users {
		userJSON, _ := json.Marshal(user)
		ctx.GetStub().PutState("user_"+user.ID, userJSON)
	}

	ctx.GetStub().PutState("tx_count", []byte("0"))
	return nil
}

// ===================================================================
// ACCOUNT FUNCTIONS
// ===================================================================
func (s *SmartContract) CreateAccount(ctx contractapi.TransactionContextInterface, id, bank, currency, accType, initialBalance string) error {
	exists, _ := s.AccountExists(ctx, id)
	if exists {
		return fmt.Errorf("account %s already exists", id)
	}
	account := Account{ID: id, Bank: bank, Currency: currency, Type: accType, Available: initialBalance}
	accJSON, _ := json.Marshal(account)
	return ctx.GetStub().PutState("account_"+id, accJSON)
}

func (s *SmartContract) GetAccount(ctx contractapi.TransactionContextInterface, id string) (*Account, error) {
	data, _ := ctx.GetStub().GetState("account_" + id)
	if data == nil {
		return nil, fmt.Errorf("account %s does not exist", id)
	}
	var account Account
	json.Unmarshal(data, &account)
	return &account, nil
}

func (s *SmartContract) AccountExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	data, _ := ctx.GetStub().GetState("account_" + id)
	return data != nil, nil
}

func (s *SmartContract) GetAllAccounts(ctx contractapi.TransactionContextInterface) ([]*Account, error) {
	results, _ := ctx.GetStub().GetStateByRange("account_", "account_zzzz")
	defer results.Close()
	var accounts []*Account
	for results.HasNext() {
		res, _ := results.Next()
		var acc Account
		json.Unmarshal(res.Value, &acc)
		accounts = append(accounts, &acc)
	}
	return accounts, nil
}

func (s *SmartContract) updateAccountBalance(ctx contractapi.TransactionContextInterface, id, newBalance string) error {
	account, _ := s.GetAccount(ctx, id)
	account.Available = newBalance
	accJSON, _ := json.Marshal(account)
	return ctx.GetStub().PutState("account_"+id, accJSON)
}

// ===================================================================
// TOKEN FUNCTIONS (Mint / Transfer)
// ===================================================================
func (s *SmartContract) Mint(ctx contractapi.TransactionContextInterface, to, amount string) (string, error) {
	exists, _ := s.AccountExists(ctx, to)
	if !exists {
		return "", fmt.Errorf("account %s does not exist", to)
	}
	account, _ := s.GetAccount(ctx, to)
	avail, _ := strconv.ParseUint(account.Available, 10, 64)
	amt, _ := strconv.ParseUint(amount, 10, 64)
	newBal := strconv.FormatUint(avail+amt, 10)
	s.updateAccountBalance(ctx, to, newBal)

	// Record transaction
	txID := ctx.GetStub().GetTxID()
	ts, _ := ctx.GetStub().GetTxTimestamp()
	tx := Transaction{
		ID:        txID,
		From:      "",
		To:        to,
		Amount:    amount,
		Block:     strconv.FormatUint(uint64(ts.Seconds), 10),
		Timestamp: time.Unix(ts.Seconds, int64(ts.Nanos)).Format("02/01/2006, 15:04:05"),
	}
	txJSON, _ := json.Marshal(tx)
	ctx.GetStub().PutState("tx_"+txID, txJSON)
	s.incrementTxCount(ctx)
	return txID, nil
}

func (s *SmartContract) Transfer(ctx contractapi.TransactionContextInterface, from, to, amount string) (string, error) {
	// Vérification de l'existence des comptes
	fromExists, _ := s.AccountExists(ctx, from)
	if !fromExists {
		return "", fmt.Errorf("account %s does not exist", from)
	}
	toExists, _ := s.AccountExists(ctx, to)
	if !toExists {
		return "", fmt.Errorf("account %s does not exist", to)
	}

	fromAcc, _ := s.GetAccount(ctx, from)
	fromBal, _ := strconv.ParseUint(fromAcc.Available, 10, 64)
	amt, _ := strconv.ParseUint(amount, 10, 64)

	if fromBal < amt {
		return "", fmt.Errorf("insufficient balance in account %s", from)
	}

	toAcc, _ := s.GetAccount(ctx, to)
	toBal, _ := strconv.ParseUint(toAcc.Available, 10, 64)

	newFromBal := strconv.FormatUint(fromBal-amt, 10)
	newToBal := strconv.FormatUint(toBal+amt, 10)

	s.updateAccountBalance(ctx, from, newFromBal)
	s.updateAccountBalance(ctx, to, newToBal)

	// Record transaction
	txID := ctx.GetStub().GetTxID()
	ts, _ := ctx.GetStub().GetTxTimestamp()
	tx := Transaction{
		ID:        txID,
		From:      from,
		To:        to,
		Amount:    amount,
		Block:     strconv.FormatUint(uint64(ts.Seconds), 10),
		Timestamp: time.Unix(ts.Seconds, int64(ts.Nanos)).Format("02/01/2006, 15:04:05"),
	}
	txJSON, _ := json.Marshal(tx)
	ctx.GetStub().PutState("tx_"+txID, txJSON)
	s.incrementTxCount(ctx)
	return txID, nil
}

// ===================================================================
// TRANSACTION FUNCTIONS
// ===================================================================
func (s *SmartContract) GetAllTransactions(ctx contractapi.TransactionContextInterface) ([]*Transaction, error) {
	results, _ := ctx.GetStub().GetStateByRange("tx_", "tx_zzzz")
	defer results.Close()
	var txs []*Transaction
	for results.HasNext() {
		res, _ := results.Next()
		var tx Transaction
		json.Unmarshal(res.Value, &tx)
		txs = append(txs, &tx)
	}
	return txs, nil
}

func (s *SmartContract) incrementTxCount(ctx contractapi.TransactionContextInterface) error {
	countBytes, _ := ctx.GetStub().GetState("tx_count")
	count, _ := strconv.ParseUint(string(countBytes), 10, 64)
	count++
	return ctx.GetStub().PutState("tx_count", []byte(strconv.FormatUint(count, 10)))
}

// ===================================================================
// USER FUNCTIONS
// ===================================================================
func (s *SmartContract) CreateUser(ctx contractapi.TransactionContextInterface, id, name, email, role string, active bool) error {
	exists, _ := s.UserExists(ctx, id)
	if exists {
		return fmt.Errorf("user %s already exists", id)
	}
	user := User{ID: id, Name: name, Email: email, Role: role, Active: active}
	userJSON, _ := json.Marshal(user)
	return ctx.GetStub().PutState("user_"+id, userJSON)
}

func (s *SmartContract) GetUser(ctx contractapi.TransactionContextInterface, id string) (*User, error) {
	data, _ := ctx.GetStub().GetState("user_" + id)
	if data == nil {
		return nil, fmt.Errorf("user %s does not exist", id)
	}
	var user User
	json.Unmarshal(data, &user)
	return &user, nil
}

func (s *SmartContract) UserExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	data, _ := ctx.GetStub().GetState("user_" + id)
	return data != nil, nil
}

func (s *SmartContract) GetAllUsers(ctx contractapi.TransactionContextInterface) ([]*User, error) {
	results, _ := ctx.GetStub().GetStateByRange("user_", "user_zzzz")
	defer results.Close()
	var users []*User
	for results.HasNext() {
		res, _ := results.Next()
		var user User
		json.Unmarshal(res.Value, &user)
		users = append(users, &user)
	}
	return users, nil
}

// UpdateUser updates an existing user's name, email, role, and active status
func (s *SmartContract) UpdateUser(ctx contractapi.TransactionContextInterface, id, name, email, role string, active bool) error {
	exists, _ := s.UserExists(ctx, id)
	if !exists {
		return fmt.Errorf("user %s does not exist", id)
	}
	user := User{ID: id, Name: name, Email: email, Role: role, Active: active}
	userJSON, _ := json.Marshal(user)
	return ctx.GetStub().PutState("user_"+id, userJSON)
}

// UpdateAccount updates an existing account's bank, currency, type, and blocked status
func (s *SmartContract) UpdateAccount(ctx contractapi.TransactionContextInterface, id, bank, currency, accType string, blocked bool) error {
	account, err := s.GetAccount(ctx, id)
	if err != nil {
		return err
	}
	account.Bank = bank
	account.Currency = currency
	account.Type = accType
	account.Blocked = blocked
	accJSON, _ := json.Marshal(account)
	return ctx.GetStub().PutState("account_"+id, accJSON)
}

// ===================================================================
// STATISTICS
// ===================================================================
func (s *SmartContract) GetDashboardStats(ctx contractapi.TransactionContextInterface) (*DashboardStats, error) {
	// Récupérer le nombre de transactions
	txCountBytes, _ := ctx.GetStub().GetState("tx_count")
	txCount, _ := strconv.ParseUint(string(txCountBytes), 10, 64)

	// Récupérer les utilisateurs actifs
	users, _ := s.GetAllUsers(ctx)
	activeUsers := uint64(0)
	for _, u := range users {
		if u.Active {
			activeUsers++
		}
	}

	// Récupérer les comptes pour calculer les blocs simulés
	accounts, _ := s.GetAllAccounts(ctx)
	blocks := uint64(len(accounts) + len(users))

	// Statistiques simulées pour la démo
	stats := &DashboardStats{
		Blocks:             blocks,
		TotalTransactions:  txCount,
		ActivePeers:        4,
		ActiveOrderers:     3,
		NetworkPerformance: 100,
		AvgTPS:             15.5,
		BreakTPS:           22.3,
		ActiveUsers:        activeUsers,
	}
	return stats, nil
}

// ===================================================================
// MAIN - CCAAS
// ===================================================================
func main() {
	chaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		fmt.Printf("Error creating chaincode: %s\n", err.Error())
		os.Exit(1)
	}

	server := &shim.ChaincodeServer{
		CCID:    os.Getenv("CHAINCODE_ID"),
		Address: os.Getenv("CHAINCODE_SERVER_ADDRESS"),
		CC:      chaincode,
		TLSProps: shim.TLSProperties{
			Disabled: true,
		},
	}

	if err := server.Start(); err != nil {
		fmt.Printf("Error starting chaincode server: %s\n", err.Error())
		os.Exit(1)
	}
}
