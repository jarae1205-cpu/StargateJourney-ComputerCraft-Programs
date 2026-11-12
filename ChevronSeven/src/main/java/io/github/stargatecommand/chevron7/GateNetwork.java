package io.github.stargatecommand.chevron7;

import java.util.Collections;
import java.util.Map;
import java.util.TreeMap;

import javax.annotation.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.Registries;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.Tag;
import net.minecraft.resources.ResourceKey;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.saveddata.SavedData;

/**
 * Every gate on the server, by address. Kept with the overworld's saved data.
 */
public class GateNetwork extends SavedData
{
	public record Entry(int[] address, ResourceKey<Level> dimension, BlockPos pos) {}

	private final Map<String, Entry> gates = new TreeMap<>();

	public static GateNetwork get(MinecraftServer server)
	{
		return server.overworld().getDataStorage().computeIfAbsent(GateNetwork::load, GateNetwork::new, "chevron7_network");
	}

	@Nullable
	public Entry find(int[] address)
	{
		return gates.get(GateAddress.key(address));
	}

	public void put(int[] address, ResourceKey<Level> dimension, BlockPos pos)
	{
		gates.put(GateAddress.key(address), new Entry(address.clone(), dimension, pos.immutable()));
		setDirty();
	}

	/** Removes the address if it still belongs to the gate at that place. */
	public void remove(int[] address, ResourceKey<Level> dimension, BlockPos pos)
	{
		Entry entry = find(address);
		if(entry != null && entry.dimension().equals(dimension) && entry.pos().equals(pos))
		{
			gates.remove(GateAddress.key(address));
			setDirty();
		}
	}

	public Map<String, Entry> all()
	{
		return Collections.unmodifiableMap(gates);
	}

	@Override
	public CompoundTag save(CompoundTag tag)
	{
		ListTag list = new ListTag();
		for(Entry entry : gates.values())
		{
			CompoundTag gate = new CompoundTag();
			gate.putIntArray("Address", entry.address());
			gate.putString("Dimension", entry.dimension().location().toString());
			gate.putLong("Pos", entry.pos().asLong());
			list.add(gate);
		}
		tag.put("Gates", list);
		return tag;
	}

	public static GateNetwork load(CompoundTag tag)
	{
		GateNetwork network = new GateNetwork();
		for(Tag element : tag.getList("Gates", Tag.TAG_COMPOUND))
		{
			CompoundTag gate = (CompoundTag) element;
			int[] address = gate.getIntArray("Address");
			ResourceLocation dimension = ResourceLocation.tryParse(gate.getString("Dimension"));
			if(!GateAddress.valid(address) || dimension == null)
				continue;
			network.gates.put(GateAddress.key(address), new Entry(address, ResourceKey.create(Registries.DIMENSION, dimension),
					BlockPos.of(gate.getLong("Pos"))));
		}
		return network;
	}
}
