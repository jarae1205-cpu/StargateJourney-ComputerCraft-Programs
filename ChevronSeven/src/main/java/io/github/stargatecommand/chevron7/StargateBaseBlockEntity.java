package io.github.stargatecommand.chevron7;

import net.minecraft.core.BlockPos;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

/**
 * Keeps a gate's address and look while it is taken apart, so it comes back the same gate.
 * The base's item carries them too (its loot table copies them).
 */
public class StargateBaseBlockEntity extends BlockEntity
{
	private int[] address = new int[0];
	private String look = "";

	public StargateBaseBlockEntity(BlockPos pos, BlockState state)
	{
		super(Chevron7.STARGATE_BASE_ENTITY.get(), pos, state);
	}

	public int[] getAddress()
	{
		return address.clone();
	}

	public String getLook()
	{
		return look;
	}

	public void remember(int[] address, String look)
	{
		this.address = address.clone();
		this.look = look == null ? "" : look;
		setChanged();
	}

	@Override
	protected void saveAdditional(CompoundTag tag)
	{
		super.saveAdditional(tag);
		tag.putIntArray("Address", address);
		tag.putString("Look", look);
	}

	@Override
	public void load(CompoundTag tag)
	{
		super.load(tag);
		address = tag.getIntArray("Address");
		look = tag.getString("Look");
	}
}
