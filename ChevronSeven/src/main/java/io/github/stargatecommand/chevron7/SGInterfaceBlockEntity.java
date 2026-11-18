package io.github.stargatecommand.chevron7;

import javax.annotation.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

/**
 * Holds the interface's computer peripheral, made by the ComputerCraft integration when a
 * computer first asks for it.
 */
public class SGInterfaceBlockEntity extends BlockEntity
{
	/** Something that keeps itself attached to the right gate; checked twice a second on the server. */
	public interface Linked
	{
		void relink();
	}

	@Nullable
	public Object peripheral;

	public SGInterfaceBlockEntity(BlockPos pos, BlockState state)
	{
		super(Chevron7.SG_INTERFACE_ENTITY.get(), pos, state);
	}

	@Nullable
	public StargateBlockEntity gate()
	{
		return level == null ? null : GateShape.nearestGate(level, worldPosition, SGInterfaceBlock.RANGE);
	}

	public static void serverTick(Level level, BlockPos pos, BlockState state, SGInterfaceBlockEntity entity)
	{
		if(level.getGameTime() % 10 == 0 && entity.peripheral instanceof Linked linked)
			linked.relink();
	}
}
