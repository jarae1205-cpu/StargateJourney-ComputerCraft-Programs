package io.github.stargatecommand.chevron7;

import java.util.function.Supplier;

import net.minecraft.core.BlockPos;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraftforge.network.NetworkDirection;
import net.minecraftforge.network.NetworkEvent;
import net.minecraftforge.network.NetworkRegistry;
import net.minecraftforge.network.simple.SimpleChannel;

public final class Net
{
	private Net() {}

	// 2: a key press names the gate picked on the DHD
	private static final String VERSION = "2";
	public static final SimpleChannel CHANNEL = NetworkRegistry.newSimpleChannel(Chevron7.id("main"), () -> VERSION, VERSION::equals, VERSION::equals);

	public static final int DIAL_BUTTON = -1;
	public static final int IRIS_BUTTON = -2;

	public static void register()
	{
		CHANNEL.messageBuilder(DhdPress.class, 0, NetworkDirection.PLAY_TO_SERVER)
				.encoder(DhdPress::encode).decoder(DhdPress::decode).consumerMainThread(DhdPress::handle).add();
	}

	/**
	 * A key of the DHD was pressed: a symbol (0-38), the dial button or the iris button.
	 * {@code gate} is the gate picked on the DHD's screen when several are in range (or null).
	 */
	public record DhdPress(BlockPos dhd, int key, @javax.annotation.Nullable BlockPos gate)
	{
		void encode(FriendlyByteBuf buffer)
		{
			buffer.writeBlockPos(dhd);
			buffer.writeVarInt(key);
			buffer.writeBoolean(gate != null);
			if(gate != null)
				buffer.writeBlockPos(gate);
		}

		static DhdPress decode(FriendlyByteBuf buffer)
		{
			BlockPos dhd = buffer.readBlockPos();
			int key = buffer.readVarInt();
			BlockPos gate = buffer.readBoolean() ? buffer.readBlockPos() : null;
			return new DhdPress(dhd, key, gate);
		}

		void handle(Supplier<NetworkEvent.Context> context)
		{
			ServerPlayer player = context.get().getSender();
			if(player == null || player.distanceToSqr(dhd.getX() + 0.5, dhd.getY() + 0.5, dhd.getZ() + 0.5) > 64
					|| !player.level().getBlockState(dhd).is(Chevron7.DHD.get()))
				return;
			StargateBlockEntity gate = GateShape.chosenGate(player.level(), dhd, DHDBlock.RANGE, this.gate);
			if(gate == null)
			{
				player.displayClientMessage(Component.translatable("message.chevron7.no_gate"), true);
				return;
			}
			int result;
			if(key == IRIS_BUTTON)
				result = gate.setIris(!gate.isIrisClosing()) ? 0 : StargateBlockEntity.NOT_ALLOWED;
			else if(key == DIAL_BUTTON)
				result = gate.dhdButton();
			else
				result = gate.engageSymbol(key, true);
			player.level().playSound(null, dhd, key == DIAL_BUTTON ? SoundEvents.STONE_BUTTON_CLICK_ON : SoundEvents.STONE_PRESSURE_PLATE_CLICK_ON,
					SoundSource.BLOCKS, 0.6F, key == DIAL_BUTTON ? 0.7F : 1.4F);
			if(result < 0 && result != StargateBlockEntity.SYMBOL_IN_ADDRESS)
				player.displayClientMessage(Component.translatable("feedback.chevron7." + gate.getFeedbackText()), true);
		}
	}
}
