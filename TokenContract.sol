// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract tokenContract is
    IERC20,
    IERC20Metadata,
    Pausable,
    ReentrancyGuard
{
    address private _owner;

    mapping(address => uint256) private _balances;
    mapping(address => bool) private blacklist;

    uint256 private _totalTax ;
    uint256 private _teamTax ;
    uint256 private _marketingTax ;
    address private _teamAddress; // Wallet Address for Team Tax
    address private _marketingAddress; // Wallet Address for Marketing Tax
    uint256 private _maxTxPercent ;
    uint256 constant private _totalSupplyLimit = (1000 * (10**6)) * 10 ** 18;  // 1b tokens for distribution

    uint256 private _maxTxAmount;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;  // 1b tokens for distribution
    string private _name;
    string private _symbol;

    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) private _isExcludedFromLimits;

    address constant public DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant private ZERO = 0x0000000000000000000000000000000000000000;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address teamAddress_,
        address marketingAddress_,
        uint256 teamTax_,
        uint256 marketingTax_,
        uint256 maxTxPercent_
        )
    {
        _owner = msg.sender;
        _name = name_;
        _symbol = symbol_;
        _mint(msg.sender, _totalSupplyLimit);
        _teamAddress = teamAddress_;
        _marketingAddress = marketingAddress_;
        _isExcludedFromFees[_owner] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[DEAD] = true;
        _isExcludedFromLimits[_owner] = true;
        _teamTax = teamTax_;
        _marketingTax = marketingTax_;
        _maxTxPercent = maxTxPercent_;

        _maxTxAmount = (_totalSupplyLimit * _maxTxPercent) / 100;

        _totalTax = _teamTax + _marketingTax;

        _approve(_owner, address(this) , type(uint256).max);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupplyLimit;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) whenNotPaused nonReentrant external override returns (bool) {
        require(!isBlacklisted(msg.sender), "BlackListed Address!!!");
        return _transfer(msg.sender, recipient, amount);
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner_, address spender) public view virtual override returns (uint256) {
        return _allowances[owner_][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) whenNotPaused nonReentrant public virtual override returns (bool) {
        require(!isBlacklisted(msg.sender), "BlackListed Address!!!");
        address owner_ = _msgSender();
        _approve(owner_, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) whenNotPaused nonReentrant public virtual override returns (bool) {
        require(!isBlacklisted(msg.sender), "BlackListed Address!!!");
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) whenNotPaused nonReentrant public virtual returns (bool) {
        require(!isBlacklisted(msg.sender), "BlackListed Address!!!");
        address owner_ = _msgSender();
        _approve(owner_, spender, allowance(owner_, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) whenNotPaused nonReentrant public virtual returns (bool) {
        require(!isBlacklisted(msg.sender), "BlackListed Address!!!");
        address owner_ = _msgSender();
        uint256 currentAllowance = allowance(owner_, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner_, spender, currentAllowance - subtractedValue);
        }

        return true;
    }



    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     *    onlyOwner can call when contract is not paused
     */
    function burn( uint256 amount) whenNotPaused external{
        require(!isBlacklisted(msg.sender), "BlackListed Address!!!");
        _burn(msg.sender, amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner_, address spender, uint256 amount) internal virtual {
        require(owner_ != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner_, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner_, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner_, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev To Pause Contract Functionalities.
     * Requirements: Caller Must be Owner
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev To UnPause Contract Functionalities.
     * Requirements: 
     *      Caller Must be Owner
     *      Contract should be unpaused
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev To get balance of BNB .
     */
    function getBNBbalance(address account) public view returns (uint256) {
        return account.balance;
    }

    /**
     * @dev To Add user to blacklist.
     * Requirements: 
     *      Caller Must be Owner
     *      Contract should be unpaused
     * Inputs:
     *      Wallet Address of user to be added.
     */
    function addToBlacklist(
        address account)
        whenNotPaused
        external
        onlyOwner
    {
        blacklist[account] = true;
    }

    /**
     * @dev To Remove user from blacklist.
     * Requirements: 
     *      Caller Must be Owner
     *      Contract should be unpaused
     * Inputs:
     *      Wallet Address of user to be removed.
     */
    function removeFromBlacklist(
        address account)
        whenNotPaused
        external
        onlyOwner
    {
        blacklist[account] = false;
    }

    /**
     * @dev To check whether user is blacklisted or not.
     * Inputs:
     *      Wallet Address of user to be checked.
     */
    function isBlacklisted(
        address account)
        public
        view
        returns (bool)
    {
        return blacklist[account];
    }

    /**
     * @dev To set  tax.
     * Requirements: 
     *      Caller Must be Owner
     *      Contract should be unpaused
     * Inputs:
     *      New Team Tax Percentage
     *      New Marketing Tax Percentage
     */
    function setTax(
        uint256 _newTeamTax,
        uint256 _newMarketingTax)
        whenNotPaused
        public
        onlyOwner
    {
        _teamTax = _newTeamTax;
        _marketingTax = _newMarketingTax;
        _totalTax = _teamTax + _marketingTax;
    }
    
    /**
     * @dev To set wallet address of team to whom team tax will be paid.
     * Requirements: 
     *      Caller Must be Owner
     *      Contract should be unpaused
     * Inputs:
     *      New Address to be set.
     */
    function setTeamAddress(
        address _newAddress)
        whenNotPaused
        public
        onlyOwner
    {
        require(_newAddress != address(0), "Zero Address Given");
        _teamAddress = _newAddress;
    }


    /**
     * @dev To set wallet address of marketing team to whom marketing tax will be paid.
     * Requirements: 
     *      Caller Must be Owner
     *      Contract should be unpaused
     * Inputs:
     *      New Address to be set.
     */
    function setMarketingAddress(
        address _newAddress)
        whenNotPaused
        public
        onlyOwner
    {
        require(_newAddress != address(0), "Zero Address Given");
        _marketingAddress = _newAddress;
    }

    /**
     * @dev To get total tax percentage.
     *
     */
    function totalTax() public view returns (uint256) {
        return _totalTax;
    }

    /**
     * @dev To get team tax percentage.
     *
     */
    function teamTax() public view returns (uint256) {
        return _teamTax;
    }

    /**
     * @dev To get marketing tax percentage.
     *
     */
    function marketingTax() public view returns (uint256) {
        return _marketingTax;
    }

    /**
     * @dev To get team address.
     *
     */
    function teamAddress() public view returns (address) {
        return _teamAddress;
    }

    /**
     * @dev To get marketing address.
     *
     */
    function marketingAddress() public view returns (address) {
        return _marketingAddress;
    }

    function owner() public view returns (address) {
        return _owner;
    }

  

    





 



//===============================================================================================================
//===============================================================================================================
//===============================================================================================================
    // Ownable removed as a lib and added here to allow for custom transfers and renouncements.
    // This allows for removal of ownership privileges from the owner once renounced or transferred.
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Call renounceOwnership to transfer owner to the zero address.");
        require(newOwner != DEAD, "Call renounceOwnership to transfer owner to the zero address.");
        _isExcludedFromFees[_owner] = false;
 
        _isExcludedFromFees[newOwner] = true;

        
        if(balanceOf(_owner) > 0) {
            _finalizeTransfer(_owner, newOwner, balanceOf(_owner), false);
        }
        
        _owner = newOwner;
        emit OwnershipTransferred(_owner, newOwner);
        
    }

    function renounceOwnership() public virtual onlyOwner {
        _isExcludedFromFees[_owner] = false;
        _owner = address(0);
        emit OwnershipTransferred(_owner, address(0));
    }
//===============================================================================================================
//===============================================================================================================
//===============================================================================================================


    function isExcludedFromLimits(address account) public view returns (bool) {
        return _isExcludedFromLimits[account];
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function setExcludedFromLimits(address account, bool enabled) whenNotPaused external onlyOwner {
        require(account != address(0), "Zero Address Given");
        _isExcludedFromLimits[account] = enabled;
    }

    function setExcludedFromFees(address account, bool enabled) whenNotPaused public onlyOwner {
        require(account != address(0), "Zero Address Given");
        _isExcludedFromFees[account] = enabled;
    }

    function setMaxTxPercent(uint256 newMaxTxPercent) whenNotPaused external onlyOwner {
        require((newMaxTxPercent > 0) && (newMaxTxPercent < 100),"Max Tx Percent should be  greater than 0 and less than 100");
        _maxTxPercent = newMaxTxPercent;
        _maxTxAmount = (_totalSupplyLimit * _maxTxPercent) / 100;
    }


    function getMaxTX() public view returns (uint256) {
        return _maxTxPercent;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 fromBalance = balanceOf(from);
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        
        if(!_isExcludedFromLimits[from])
        {
            require(amount <= _maxTxAmount,"Tx Limit Exceeded");
        }

        bool takeFee = true;
        
        if(_isExcludedFromFees[from]){
            takeFee = false;
        }


        return _finalizeTransfer(from, to, amount, takeFee);
    }

    function _finalizeTransfer(address from, address to, uint256 amount, bool takeFee) internal returns (bool) {

        uint256 amountReceived = amount;
        if (takeFee) {
            amountReceived = takeTaxes(from, amount);
        }

        uint256 fromBalance = balanceOf(from);
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] = _balances[to] + amountReceived;
        }

        emit Transfer(from, to, amountReceived);
        return true;
    }

    

    function takeTaxes(address from, uint256 amount) internal returns (uint256) {
        
        uint256 teamTaxFee = amount * teamTax() / 100;
        uint256 marketingTaxFee = amount * marketingTax() / 100;
        _balances[_teamAddress] = _balances[_teamAddress] + teamTaxFee;
        _balances[_marketingAddress] = _balances[_marketingAddress] + marketingTaxFee;

        emit Transfer(from, _teamAddress, teamTaxFee);
        emit Transfer(from, _marketingAddress, marketingTaxFee);
        return amount - teamTaxFee - marketingTaxFee;
    }

}
