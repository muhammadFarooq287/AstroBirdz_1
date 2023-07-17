// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
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
    Context,
    IERC20,
    IERC20Metadata,
    Pausable,
    Ownable,
    ReentrancyGuard
{
    mapping(address => uint256) private _balances;
    mapping(address => bool) private blacklist;
    uint256 private _totalTax = 3;
    uint256 private _teamTax = 1;
    uint256 private _marketingTax = 2;
    address private _teamAddress; // Wallet Address for Team Tax
    address private _marketingAddress; // Wallet Address for Marketing Tax
    uint256 private _maxSellLimit = 5000000 * 10 ** decimals(); // Max No of Tokens a User can Sell at a Time 
    uint256 private _lockTime = 24 hours; //Time limit

    mapping(address => uint256) private sellLimits;
    mapping(address => uint256) private lastSellTimestamp;


    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply = 1000 * (10**6) * 10** decimals();  // 1b tokens for distribution
    string private _name;
    string private _symbol;

    ///@notice Parameter errors
    error Blacklisted__Address();
    error Not_Enough_Balance_And_Tax();
    error Zero_Token();
    error Sell_Limit_Exceeded();
    error Locked_For_Selling();
    

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(
        string memory name_,
        string memory symbol_)
    {
        _name = name_;
        _symbol = symbol_;
        _mint(msg.sender, 10000);
        _pause();
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
        return _totalSupply;
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
    function transfer(address to, uint256 amount) whenNotPaused public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
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
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
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
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
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
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
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
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
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
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
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
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
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
     * @dev To set total percentage of tax.
     * Requirements: 
     *      Caller Must be Owner
     *      Contract should be unpaused
     * Inputs:
     *      Percentage to be set.
     */
    function setTotalTax(
        uint256 _percentage)
        whenNotPaused
        public
        onlyOwner
    {
        _totalTax = _percentage;
    }

    /**
     * @dev To set percentage of team tax.
     * Requirements: 
     *      Caller Must be Owner
     *      Contract should be unpaused
     * Inputs:
     *      Percentage to be set.
     */
    function setTeamTax(
        uint256 _percentage)
        whenNotPaused
        public
        onlyOwner
    {
        _teamTax = _percentage;
    }

    /**
     * @dev To set percentage of marketing tax.
     * Requirements: 
     *      Caller Must be Owner
     *      Contract should be unpaused
     * Inputs:
     *      Percentage to be set.
     */
    function setMarketingTax(
        uint256 _percentage)
        whenNotPaused
        public
        onlyOwner
    {
        _marketingTax = _percentage;
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

    /**
     * @dev To set Max Sell Limit which can be sale at a time.
     * Requirements:
     *      Caller must be Owner.
     *      Contract must be unpaused.
     * Inputs:
     *      New selling limit.
     */
    function setMaxSellLimit(
        uint256 _newLimit)
        whenNotPaused
        public
        onlyOwner
    {
        _maxSellLimit = _newLimit;
    }

    /**
     * @dev To set Lock Limit for which selling limit will be set.
     * Requirements:
     *      Caller must be Owner.
     *      Contract must be unpaused.
     * Inputs:
     *      New Lock Time in Seconds.
     */
    function setLockTime(
        uint256 _newTimeInSeconds)
        whenNotPaused
        public
        onlyOwner
    {
        _lockTime = _newTimeInSeconds;
    }

    /**
     * @dev To get max selling limit.
     *
     */
    function maxSellLimit() public view returns (uint256) {
        return _maxSellLimit;
    }

    /**
     * @dev To get lock time.
     *
     */
    function lockTime() public view returns (uint256) {
        return _lockTime;
    }

    /**
     * @dev To get reamining selling limit of user.
     * Inputs:
     *      wallet address
     */
    function getRemainingSellLimit(address account) public view returns (uint256) {
        if (block.timestamp >= lastSellTimestamp[account] + lockTime()) {
            return maxSellLimit();
        } else {
            return maxSellLimit() - sellLimits[account];
        }
    }

    /**
     * @dev To buy ABZ Tokens.
     * Requirements:
     *      Contract must be unpaused.
     * Inputs:
     *      Amount of ABZ Tokens You want to Buy.
     */
    function buyTokens(
        uint256 _amount)
        whenNotPaused
        nonReentrant
        external
        payable
    {

        uint256 bnbAmount = _amount / 1000; // 1 BNB = 1000 ABZ tokens, adjust as needed
        uint256 teamTaxFee = (bnbAmount * teamTax()) / 100 * (10 ** decimals());
        uint256 marketingTaxFee = (_amount * marketingTax()) / 100 * (10 ** decimals());

        if (isBlacklisted(msg.sender))
        {
            revert Blacklisted__Address();
        }

        if (_amount == 0)
        {
            revert Zero_Token();
        }

        if (balanceOf(_msgSender()) < (bnbAmount + teamTaxFee + marketingTaxFee))
        {
            revert Not_Enough_Balance_And_Tax();
        }

        payable(teamAddress()).transfer(teamTaxFee);
        payable(marketingAddress()).transfer(marketingTaxFee);
        payable(address(this)).transfer(bnbAmount);

        _mint(msg.sender, _amount);
    }

    /**
     * @dev To sell ABZ Tokens.
     * Requirements:
     *      Contract must be unpaused.
     * Inputs:
     *      Amount of ABZ tokens You want to Sell.
     */
    function sellToken(
        uint256 _amount)
        whenNotPaused
        nonReentrant
        external
    {
        uint256 ethToTransfer = _amount / 1000 * (10 ** decimals()); // 1 ABZ token = 0.001 ETH, adjust as needed
        uint256 teamTaxFee = ((ethToTransfer * _teamTax) / 100) * (10 ** decimals());
        uint256 marketingTaxFee = (ethToTransfer * _marketingTax) / 100* (10 ** decimals());

        if (isBlacklisted(msg.sender))
        {
            revert Blacklisted__Address();
        }

        if (_amount == 0)
        {
            revert Zero_Token();
        }

        if (balanceOf(_msgSender()) < (ethToTransfer + teamTaxFee + marketingTaxFee))
        {
            revert Not_Enough_Balance_And_Tax();
        }

        if (_amount > getRemainingSellLimit(msg.sender))
        {
            revert Sell_Limit_Exceeded();
        }

        if (lastSellTimestamp[msg.sender] + lockTime() > block.timestamp)
        {
            revert Locked_For_Selling();
        }

        sellLimits[msg.sender] -= _amount;
        lastSellTimestamp[msg.sender] = block.timestamp;
        _burn(msg.sender, _amount);

        payable(teamAddress()).transfer(teamTaxFee);
        payable(marketingAddress()).transfer(marketingTaxFee);
            
    } 

}

