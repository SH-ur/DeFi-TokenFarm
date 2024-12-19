// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./DappToken.sol";
import "./LPToken.sol";
//This contract is from ssmanzanilla2@gmail.com. Hi!
/**
 * @title Proportional Token Farm
 * @notice Una granja de staking donde las recompensas se distribuyen proporcionalmente al total stakeado.
 */
contract TokenFarm {
    //
    // Variables de estado
    //
    string public name = "Proportional Token Farm";
    address payable public owner;
    DAppToken public dappToken;
    LPToken public lpToken;

    struct UserStruct{
        uint256 stakingBalance;
        uint256 checkpoints;
        uint256 pendingRewards;
        bool hasStaked;
        bool isStaking;
    }
    modifier userIsStaking(){
        require(user[msg.sender].isStaking == true, "The user is not staking");
        _;
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "Only the owner can do that.");
        _;
    }
    uint256 public REWARD_PER_BLOCK; // Recompensa por bloque (total para todos los usuarios)... Hasta que coloqué el Bonus y se pueden usar Rangos :)
    uint256 public minReward;
    uint256 public maxReward;
    uint256 public feeVar;
    uint256 private totalFee;
    uint256 public totalStakingBalance; // Total de tokens en staking
    
    address[] public stakers;
    
    mapping(address => UserStruct) public user;
    // Eventos
    // Agregar eventos para Deposit, Withdraw, RewardsClaimed y RewardsDistributed.
    event Deposit(address sender, uint256 amount);
    event Withdraw(address sender, uint256 amount);
    event RewardsClaimed(uint256 rewardsAmount, address user);
    event RewardsDistributed(uint256 numOfUsersDistributed, string message);
    // Constructor
    constructor(DAppToken _dappToken, LPToken _lpToken, uint256 _minReward, uint256 _maxReward, uint256 _feeAmount) {
        // Configurar las instancias de los contratos de DappToken y LPToken.
        dappToken = _dappToken;
        lpToken = _lpToken;
        // Configurar al owner del contrato como el creador de este contrato.
        owner = payable(msg.sender);
        require(_feeAmount < 10000, "Fee amount cannot be greater than the 100%");
        feeVar = _feeAmount;
        require(_minReward < _maxReward, "Min Reward cannot be greater than Max Reward.");
        minReward = _minReward;
        maxReward = _maxReward;
        REWARD_PER_BLOCK = (minReward + maxReward) / 2;
    }

    /**
     * @notice Deposita tokens LP para staking.
     * @param _amount Cantidad de tokens LP a depositar.
     */
    function deposit(uint256 _amount) external {
        // Verificar que _amount sea mayor a 0.
        require(_amount > 0, "The amount cannot be lesser than 1");
        // Transferir tokens LP del usuario a este contrato.
        lpToken.transferFrom(msg.sender, address(this), _amount);
        // Actualizar el balance de staking del usuario en stakingBalance.
        user[msg.sender].stakingBalance += _amount;
        // Incrementar totalStakingBalance con _amount.
        totalStakingBalance += _amount;
        // Si el usuario nunca ha hecho staking antes, agregarlo al array stakers y marcar hasStaked como true.
        if(!user[msg.sender].hasStaked){
            stakers.push(msg.sender);
            user[msg.sender].hasStaked = true;
        }
        // Actualizar isStaking del usuario a true.
        user[msg.sender].isStaking = true;
        // Si checkpoints del usuario está vacío, inicializarlo con el número de bloque actual.
        
        if(user[msg.sender].checkpoints <= 0) user[msg.sender].checkpoints = block.number;
        // Llamar a distributeRewards para calcular y actualizar las recompensas pendientes.
        distributeRewards(msg.sender);
        // Emitir un evento de depósito.
        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice Retira todos los tokens LP en staking.
     */
    function withdraw() external userIsStaking{
        uint256 currentBalance;
        // Verificar que el usuario está haciendo staking (isStaking == true).
        // Obtener el balance de staking del usuario.
        currentBalance = user[msg.sender].stakingBalance;
        // Verificar que el balance de staking sea mayor a 0.
        require(currentBalance > 0, "Im sorry, the current staking balance of this address is empty");
        // Llamar a distributeRewards para calcular y actualizar las recompensas pendientes antes de restablecer el balance.
        distributeRewards(msg.sender);
        // Restablecer stakingBalance del usuario a 0.
        user[msg.sender].stakingBalance = 0;
        // Reducir totalStakingBalance en el balance que se está retirando.
        totalStakingBalance -= currentBalance;
        // Actualizar isStaking del usuario a false.
        user[msg.sender].isStaking = false;
        // Transferir los tokens LP de vuelta al usuario.
        lpToken.transfer(msg.sender, currentBalance);
        // Emitir un evento de retiro.
        emit Withdraw(msg.sender, currentBalance);
    }

    /**
     * @notice Reclama recompensas pendientes.
     */
    function claimRewards() external {
        // Obtener el monto de recompensas pendientes del usuario desde pendingRewards.
        uint256 pendingAmount = user[msg.sender].pendingRewards;
        // Verificar que el monto de recompensas pendientes sea mayor a 0.
        require(pendingAmount > 0, "Pending Amount is zero or lesser, we cannot continue.");
        // Restablecer las recompensas pendientes del usuario a 0.
        user[msg.sender].pendingRewards = 0;

        //Bonus: Cobrar comisión al momento de reclamar recompensas
        uint256 feeCalc = (pendingAmount * feeVar)/ 10000;
        uint totalAfterFee = pendingAmount - feeCalc;
        totalFee += feeCalc;
        // Llamar a la función de acuñación (mint) en el contrato DappToken para transferir las recompensas al usuario.
        dappToken.mint(msg.sender, totalAfterFee);
        // Emitir un evento de reclamo de recompensas.
        emit RewardsClaimed(pendingAmount, msg.sender);
    }

    function claimFee (uint256 _amount) external onlyOwner{
        require(totalFee >= _amount, "Sorry, the amount cannot be greater than the total fee on the system.");
        owner.transfer(_amount);
    }
    /**
     * @notice Distribuye recompensas a todos los usuarios en staking.
     */
    function distributeRewardsAll() external onlyOwner(){
        // Verificar que la llamada sea realizada por el owner.
        // Iterar sobre todos los usuarios en staking almacenados en el array staker s.
        for(uint256 i = 0;i < stakers.length; i++){
            if(user[stakers[i]].isStaking) distributeRewards(stakers[i]);
        }
        // Para cada usuario, si están haciendo staking (isStaking == true), llamar a distributeRewards.
        // Emitir un evento indicando que las recompensas han sido distribuidas.
        emit RewardsDistributed(stakers.length, "Successfully distributed!");
    }

    /**
     * @notice Calcula y distribuye las recompensas proporcionalmente al staking total.
     * @dev La función toma en cuenta el porcentaje de tokens que cada usuario tiene en staking con respecto
     *      al total de tokens en staking (`totalStakingBalance`).
     *
     * Funcionamiento:
     * 1. Se calcula la cantidad de bloques transcurridos desde el último checkpoint del usuario.
     * 2. Se calcula la participación proporcional del usuario:
     *    share = stakingBalance[beneficiary] / totalStakingBalance
     * 3. Las recompensas para el usuario se determinan multiplicando su participación proporcional
     *    por las recompensas por bloque (`REWARD_PER_BLOCK`) y los bloques transcurridos:
     *    reward = REWARD_PER_BLOCK * blocksPassed * share
     * 4. Se acumulan las recompensas calculadas en `pendingRewards[beneficiary]`.
     * 5. Se actualiza el checkpoint del usuario al bloque actual.
     *
     * Ejemplo Práctico:
     * - Supongamos que:
     *    Usuario A ha stakeado 100 tokens.
     *    Usuario B ha stakeado 300 tokens.
     *    Total de staking (`totalStakingBalance`) = 400 tokens.
     *    `REWARD_PER_BLOCK` = 1e18 (1 token total por bloque).
     *    Han transcurrido 10 bloques desde el último checkpoint.
     *
     * Cálculo:
     * - Participación de Usuario A:
     *   shareA = 100 / 400 = 0.25 (25%)
     *   rewardA = 1e18 * 10 * 0.25 = 2.5e18 (2.5 tokens).
     *
     * - Participación de Usuario B:
     *   shareB = 300 / 400 = 0.75 (75%)
     *   rewardB = 1e18 * 10 * 0.75 = 7.5e18 (7.5 tokens).
     *
     * Resultado:
     * - Usuario A acumula 2.5e18 en `pendingRewards`.
     * - Usuario B acumula 7.5e18 en `pendingRewards`.
     *
     * Nota:
     * Este sistema asegura que las recompensas se distribuyan proporcionalmente y de manera justa
     * entre todos los usuarios en función de su contribución al staking total.
     */
    function distributeRewards(address beneficiary) private {
        // Obtener el último checkpoint del usuario desde checkpoints.
        uint256 lastCheckpoint = user[beneficiary].checkpoints;
        // Verificar que el número de bloque actual sea mayor al checkpoint y que totalStakingBalance sea mayor a 0.
        require(lastCheckpoint < block.number && totalStakingBalance > 0, "Sorry, or the block numbers doesnt match, or the total staking balance is empty");
        // Calcular la cantidad de bloques transcurridos desde el último checkpoint. 
        uint256 blocksPassed = block.number - lastCheckpoint;
        // Calcular la proporción del staking del usuario en relación al total staking (stakingBalance[beneficiary] / totalStakingBalance).
        uint256 shareCalc = user[beneficiary].stakingBalance / totalStakingBalance;
        // Calcular las recompensas del usuario multiplicando la proporción por REWARD_PER_BLOCK y los bloques transcurridos.
        uint256 rewardCalc = REWARD_PER_BLOCK * blocksPassed * shareCalc;
        // Actualizar las recompensas pendientes del usuario en pendingRewards.
        user[beneficiary].pendingRewards = rewardCalc;
        // Actualizar el checkpoint del usuario al bloque actual.
         user[beneficiary].checkpoints = block.number;
    }

    function setReward (uint256 newReward) external onlyOwner {
        require(newReward >= minReward || newReward<= maxReward, "Sorry, you cant go beyond the min and max established values.");

        REWARD_PER_BLOCK = newReward;
    }
}