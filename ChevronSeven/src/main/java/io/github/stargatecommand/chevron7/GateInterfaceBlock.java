package io.github.stargatecommand.chevron7;

import java.util.List;

import javax.annotation.Nullable;

import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;

/**
 * Like SGCraft's computer interface: put it against any block of a gate, and a computer
 * against it. The computer sees the gate as the same "chevron7_stargate" peripheral it gets by
 * touching the ring itself (CC: Tweaked).
 */
public class GateInterfaceBlock extends Block
{
	public GateInterfaceBlock(Properties properties)
	{
		super(properties);
	}

	/** The gate this interface touches, or null. */
	@Nullable
	public static StargateBlockEntity gateNextTo(BlockGetter level, BlockPos pos)
	{
		for(Direction side : Direction.values())
		{
			BlockPos next = pos.relative(side);
			BlockState state = level.getBlockState(next);
			BlockPos core = state.is(Chevron7.GATE_FRAME.get()) ? GateFrameBlock.core(next, state) : next;
			if(level.getBlockEntity(core) instanceof StargateBlockEntity gate && !gate.isRemoved())
				return gate;
		}
		return null;
	}

	@SuppressWarnings("deprecation")
	@Override
	public void neighborChanged(BlockState state, Level level, BlockPos pos, Block block, BlockPos fromPos, boolean moving)
	{
		super.neighborChanged(state, level, pos, block, fromPos, moving);
		// a gate formed or broke next to us: tell the computer next to us to look again. Not when
		// the news came from another interface, or two of them side by side would never stop.
		if(!level.isClientSide() && !level.getBlockState(fromPos).is(this))
			level.updateNeighborsAt(pos, this);
	}

	@Override
	public void appendHoverText(ItemStack stack, @Nullable BlockGetter level, List<Component> tooltip, TooltipFlag flag)
	{
		tooltip.add(Component.translatable("tooltip.chevron7.gate_interface").withStyle(ChatFormatting.GRAY));
	}
}
