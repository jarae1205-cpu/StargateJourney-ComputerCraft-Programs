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
 * Changes how a gate looks: use it on any part of the ring for the next look, sneak to go back.
 * It isn't used up.
 */
public class LookCrystalItem extends Item
{
	public LookCrystalItem(Properties properties)
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
		GateLook look = gate.getLook().next(player != null && player.isShiftKeyDown() ? -1 : 1);
		gate.setLook(look);
		if(player != null)
			player.displayClientMessage(Component.translatable("message.chevron7.look", look.displayName()), true);
		return InteractionResult.CONSUME;
	}
}
