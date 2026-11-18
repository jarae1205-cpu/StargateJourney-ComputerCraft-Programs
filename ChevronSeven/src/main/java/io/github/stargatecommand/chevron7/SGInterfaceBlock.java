package io.github.stargatecommand.chevron7;

import javax.annotation.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityTicker;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;

/**
 * The SG computer interface: a computer next to it (or on a wired modem) controls the nearest
 * gate within {@link #RANGE} blocks the way SGCraft's computer interface does, with letter addresses.
 */
public class SGInterfaceBlock extends BaseEntityBlock
{
	public static final int RANGE = 6;

	public SGInterfaceBlock(Properties properties)
	{
		super(properties);
	}

	@Override
	public RenderShape getRenderShape(BlockState state)
	{
		return RenderShape.MODEL;
	}

	@SuppressWarnings("deprecation")
	@Override
	public InteractionResult use(BlockState state, Level level, BlockPos pos, Player player, InteractionHand hand, BlockHitResult hit)
	{
		if(!level.isClientSide())
		{
			StargateBlockEntity gate = GateShape.nearestGate(level, pos, RANGE);
			player.displayClientMessage(gate == null ? Component.translatable("message.chevron7.interface_no_gate", RANGE)
					: Component.translatable("message.chevron7.interface_gate", SGAddress.formatOf(gate.getAddress())), true);
		}
		return InteractionResult.sidedSuccess(level.isClientSide());
	}

	@Nullable
	@Override
	public BlockEntity newBlockEntity(BlockPos pos, BlockState state)
	{
		return new SGInterfaceBlockEntity(pos, state);
	}

	@Nullable
	@Override
	public <T extends BlockEntity> BlockEntityTicker<T> getTicker(Level level, BlockState state, BlockEntityType<T> type)
	{
		return level.isClientSide() ? null : createTickerHelper(type, Chevron7.SG_INTERFACE_ENTITY.get(), SGInterfaceBlockEntity::serverTick);
	}
}
