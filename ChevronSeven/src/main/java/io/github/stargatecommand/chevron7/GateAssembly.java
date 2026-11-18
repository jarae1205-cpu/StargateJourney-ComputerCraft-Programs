package io.github.stargatecommand.chevron7;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;

/**
 * Gates built SGCraft style: a Stargate Base Block with 14 Ring Blocks and 9 Chevron Blocks
 * around it in the shape of the ring. Complete, with the inside clear, they become a gate.
 * Breaking any block of such a gate turns it back into the blocks, and the base keeps the
 * gate's address and look.
 */
public final class GateAssembly
{
	private GateAssembly() {}

	public static BlockState partState(int part)
	{
		return (GateShape.isChevron(part) ? Chevron7.CHEVRON_BLOCK : Chevron7.RING_BLOCK).get().defaultBlockState();
	}

	public static ItemStack partItem(int part)
	{
		return new ItemStack(GateShape.isChevron(part) ? Chevron7.CHEVRON_BLOCK_ITEM.get() : Chevron7.RING_BLOCK_ITEM.get());
	}

	private static boolean partAt(Level level, BlockPos core, Direction facing, int part)
	{
		BlockState state = level.getBlockState(GateShape.frameCell(core, facing, part));
		return state.getBlock() instanceof GatePartBlock block && block.isChevron() == GateShape.isChevron(part);
	}

	/** {ring blocks, chevron blocks} still to place around a base. */
	public static int[] missing(Level level, BlockPos core, Direction facing)
	{
		int[] missing = new int[2];
		for(int part = 0; part < GateShape.FRAME.length; part++)
		{
			if(!partAt(level, core, facing, part))
				missing[GateShape.isChevron(part) ? 1 : 0]++;
		}
		return missing;
	}

	private static boolean insideClear(Level level, BlockPos core, Direction facing)
	{
		for(int[] cell : GateShape.INSIDE)
		{
			if(!level.getBlockState(GateShape.cell(core, facing, cell[0], cell[1])).canBeReplaced())
				return false;
		}
		return true;
	}

	/** What a player is told about a base: what is still missing, or that the ring is done. */
	public static Component status(Level level, BlockPos core, Direction facing)
	{
		int[] missing = missing(level, core, facing);
		if(missing[0] + missing[1] > 0)
			return Component.translatable("message.chevron7.base_missing", missing[0], missing[1]);
		if(!insideClear(level, core, facing))
			return Component.translatable("message.chevron7.base_inside");
		return Component.translatable("message.chevron7.base_complete");
	}

	/** Turns a base and its finished ring into a gate. */
	public static boolean tryForm(ServerLevel level, BlockPos core)
	{
		BlockState base = level.getBlockState(core);
		if(!base.is(Chevron7.STARGATE_BASE.get()))
			return false;
		Direction facing = base.getValue(StargateBaseBlock.FACING);
		int[] missing = missing(level, core, facing);
		if(missing[0] + missing[1] > 0 || !insideClear(level, core, facing))
			return false;

		int[] address = new int[0];
		String look = "";
		if(level.getBlockEntity(core) instanceof StargateBaseBlockEntity saved)
		{
			address = saved.getAddress();
			look = saved.getLook();
		}
		// the stargate block replaces the ring's blocks with its frame
		level.setBlock(core, Chevron7.STARGATE.get().defaultBlockState().setValue(StargateBlock.FACING, facing), Block.UPDATE_ALL);
		for(int part = 0; part < GateShape.FRAME.length; part++)
		{
			BlockPos cell = GateShape.frameCell(core, facing, part);
			BlockState frame = level.getBlockState(cell);
			if(frame.is(Chevron7.GATE_FRAME.get()))
				level.setBlock(cell, frame.setValue(GateFrameBlock.BUILT, true), Block.UPDATE_CLIENTS);
		}
		if(level.getBlockEntity(core) instanceof StargateBlockEntity gate)
		{
			gate.setBuiltFromParts(true);
			gate.presetAddress(address);
			GateLook saved = GateLook.byId(look);
			if(saved != null)
				gate.setLook(saved);
			gate.ensureRegistered(level);
		}
		level.playSound(null, core.above(3), SoundEvents.BEACON_ACTIVATE, SoundSource.BLOCKS, 1.0F, 0.8F);
		return true;
	}

	/** A Ring or Chevron Block was placed: form any gate whose ring it completes. */
	public static void formAround(ServerLevel level, BlockPos partPos)
	{
		for(Direction facing : Direction.Plane.HORIZONTAL)
		{
			for(int part = 0; part < GateShape.FRAME.length; part++)
			{
				BlockPos core = GateShape.coreOf(partPos, facing, part);
				BlockState state = level.getBlockState(core);
				if(state.is(Chevron7.STARGATE_BASE.get()) && state.getValue(StargateBaseBlock.FACING) == facing && tryForm(level, core))
					return;
			}
		}
	}

	/**
	 * Takes a gate built from blocks apart: the stargate block becomes the base again, keeping the
	 * address and look, and StargateBlock puts the Ring and Chevron Blocks back in the frame.
	 */
	public static void unform(ServerLevel level, BlockPos core)
	{
		if(!(level.getBlockEntity(core) instanceof StargateBlockEntity gate))
			return;
		int[] address = gate.getAddress();
		String look = gate.getLook().id;
		Direction facing = level.getBlockState(core).getValue(StargateBlock.FACING);
		level.setBlock(core, Chevron7.STARGATE_BASE.get().defaultBlockState().setValue(StargateBaseBlock.FACING, facing), Block.UPDATE_ALL);
		if(level.getBlockEntity(core) instanceof StargateBaseBlockEntity base)
			base.remember(address, look);
	}

	/** The base as an item, carrying a gate's address and look. */
	public static ItemStack baseItem(int[] address, String look)
	{
		ItemStack stack = new ItemStack(Chevron7.STARGATE_BASE_ITEM.get());
		CompoundTag tag = new CompoundTag();
		tag.putIntArray("Address", address);
		tag.putString("Look", look);
		BlockItem.setBlockEntityData(stack, Chevron7.STARGATE_BASE_ENTITY.get(), tag);
		return stack;
	}

	public static int[] savedAddress(ItemStack stack)
	{
		CompoundTag tag = BlockItem.getBlockEntityData(stack);
		return tag == null ? new int[0] : tag.getIntArray("Address");
	}
}
