package io.github.stargatecommand.jsginfinity;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.builder.LiteralArgumentBuilder;
import com.mojang.brigadier.context.CommandContext;
import com.mojang.brigadier.exceptions.CommandSyntaxException;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.commands.SharedSuggestionProvider;
import net.minecraft.commands.arguments.coordinates.BlockPosArgument;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.Entity;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

/**
 * The operator commands, each {@code <pos> [north|south|east|west]}; what's built faces the way
 * you give, or towards you:
 * <ul>
 * <li>{@code /jsginfinity build}: a whole Infinity gate with its base at pos, formed, as JSG's
 * {@code /jsg buildgate} does for its own gates.</li>
 * <li>{@code /jsginfinity platform}: the gate on the stone pyramid of Carter's Addon Pack's dial
 * sequence, with the orange DHD; pos is the ground under the gate.</li>
 * <li>{@code /jsginfinity room}: the gate room of Stargate Infinity, with the Infinity DHD; pos is
 * the floor under the gate.</li>
 * </ul>
 */
@Mod.EventBusSubscriber(modid = JSGInfinity.MOD_ID, bus = Mod.EventBusSubscriber.Bus.FORGE)
public final class InfinityCommands {
    private InfinityCommands() {}

    @FunctionalInterface
    private interface Builder {
        InfinityBaseBE build(ServerLevel level, BlockPos pos, Direction facing);
    }

    @SubscribeEvent
    public static void register(RegisterCommandsEvent event) {
        CommandDispatcher<CommandSourceStack> dispatcher = event.getDispatcher();
        dispatcher.register(Commands.literal(JSGInfinity.MOD_ID)
                .requires(source -> source.hasPermission(2))
                .then(command("build", "an Infinity gate", InfinityBuildings::gate))
                .then(command("platform", "Carter's platform with an Infinity gate", InfinityBuildings::carterPlatform))
                .then(command("room", "the Infinity gate room", InfinityBuildings::infinityRoom)));
    }

    private static LiteralArgumentBuilder<CommandSourceStack> command(String name, String what, Builder builder) {
        return Commands.literal(name)
                .then(Commands.argument("pos", BlockPosArgument.blockPos())
                        .executes(ctx -> run(ctx, null, what, builder))
                        .then(Commands.argument("facing", StringArgumentType.word())
                                .suggests((ctx, b) -> SharedSuggestionProvider.suggest(
                                        new String[]{"north", "south", "east", "west"}, b))
                                .executes(ctx -> run(ctx, StringArgumentType.getString(ctx, "facing"), what, builder))));
    }

    private static int run(CommandContext<CommandSourceStack> ctx, String facingName, String what, Builder builder)
            throws CommandSyntaxException {
        CommandSourceStack source = ctx.getSource();
        BlockPos pos = BlockPosArgument.getLoadedBlockPos(ctx, "pos");

        Direction facing;
        if (facingName != null) {
            facing = Direction.byName(facingName);
            if (facing == null || facing.getAxis().isVertical()) {
                source.sendFailure(Component.literal("Facing must be north, south, east or west"));
                return 0;
            }
        } else {
            Entity entity = source.getEntity();
            facing = entity != null ? entity.getDirection().getOpposite() : Direction.NORTH;
        }

        InfinityBaseBE gate = builder.build(source.getLevel(), pos, facing);
        if (gate == null) {
            source.sendFailure(Component.literal("Couldn't place the gate's base block"));
            return 0;
        }
        boolean formed = gate.getMergeHelper().checkMergeState();
        BlockPos base = gate.getBlockPos();
        source.sendSuccess(() -> Component.literal((formed ? "Built " : "Placed the blocks of ") + what
                + ", gate base at " + base.toShortString() + ", facing " + facing.getName()
                + (formed ? "" : ", but the gate didn't form")), true);
        return formed ? 1 : 0;
    }
}
