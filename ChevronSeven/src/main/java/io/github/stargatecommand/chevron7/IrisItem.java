package io.github.stargatecommand.chevron7;

import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;

/**
 * Fits an iris to a gate: use it on any part of the ring.
 */
public class IrisItem extends Item
{
	public IrisItem(Properties properties)
	{
		super(properties);
	}

	@Override
	public InteractionResult useOn(UseOnContext context)
	{
		Level level = context.getLevel();
		BlockPos pos = context.getClickedPos();
		BlockState state = level.getBlockState(pos);
		BlockPos core = state.is(Chevron7.GATE_FRAME.get()) ? GateFrameBlock.core(pos, state) : pos;
		if(!(level.getBlockEntity(core) instanceof StargateBlockEntity gate))
			return InteractionResult.PASS;
		if(level.isClientSide())
			return InteractionResult.SUCCESS;
		Player player = context.getPlayer();
		if(gate.isSupergate())
		{
			if(player != null)
				player.displayClientMessage(Component.translatable("message.chevron7.no_iris_supergate"), true);
			return InteractionResult.FAIL;
		}
		if(gate.hasIris())
		{
			if(player != null)
				player.displayClientMessage(Component.translatable("message.chevron7.iris_already"), true);
			return InteractionResult.FAIL;
		}
		gate.installIris();
		if(player != null)
		{
			player.displayClientMessage(Component.translatable("message.chevron7.iris_installed"), true);
			if(!player.getAbilities().instabuild)
				context.getItemInHand().shrink(1);
		}
		return InteractionResult.CONSUME;
	}
}
