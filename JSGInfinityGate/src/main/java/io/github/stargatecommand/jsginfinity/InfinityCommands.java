package io.github.stargatecommand.jsginfinity;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import com.mojang.brigadier.exceptions.CommandSyntaxException;
import dev.tauri.jsg.api.blockstates.JSGProperties;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.commands.SharedSuggestionProvider;
import net.minecraft.commands.arguments.coordinates.BlockPosArgument;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

import java.util.Map;

/**
 * {@code /jsginfinity build <pos> [north|south|east|west]}: lays out a whole Infinity gate, base,
 * rings and chevrons, and forms it, as JSG's {@code /jsg buildgate} does for its own gates. The
 * gate faces the way you give, or towards you. For operators.
 */
@Mod.EventBusSubscriber(modid = JSGInfinity.MOD_ID, bus = Mod.EventBusSubscriber.Bus.FORGE)
public final class InfinityCommands {
    private InfinityCommands() {}

    @SubscribeEvent
    public static void register(RegisterCommandsEvent event) {
        CommandDispatcher<CommandSourceStack> dispatcher = event.getDispatcher();
        dispatcher.register(Commands.literal(JSGInfinity.MOD_ID)
                .requires(source -> source.hasPermission(2))
                .then(Commands.literal("build")
                        .then(Commands.argument("pos", BlockPosArgument.blockPos())
                                .executes(ctx -> build(ctx, null))
                                .then(Commands.argument("facing", StringArgumentType.word())
                                        .suggests((ctx, builder) -> SharedSuggestionProvider.suggest(
                                                new String[]{"north", "south", "east", "west"}, builder))
                                        .executes(ctx -> build(ctx, StringArgumentType.getString(ctx, "facing")))))));
    }

    private static int build(CommandContext<CommandSourceStack> ctx, String facingName) throws CommandSyntaxException {
        CommandSourceStack source = ctx.getSource();
        ServerLevel level = source.getLevel();
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

        BlockState base = JSGInfinity.BASE_BLOCK.get().defaultBlockState()
                .setValue(JSGProperties.FACING_HORIZONTAL_PROPERTY, facing);
        level.setBlock(pos, base, 3);
        if (!(level.getBlockEntity(pos) instanceof InfinityBaseBE gate)) {
            source.sendFailure(Component.literal("Couldn't place the gate's base block"));
            return 0;
        }
        gate.generateMergeHelper();
        Map<BlockPos, BlockState> blocks = gate.getMergeHelper().getBlocks();
        for (Map.Entry<BlockPos, BlockState> block : blocks.entrySet()) {
            level.setBlock(block.getKey(), block.getValue(), 3);
        }
        // what JSG does when a player places a base block
        gate.getMergeHelper().updateMemberStateAndCheck(null);
        gate.refresh();

        boolean formed = gate.getMergeHelper().checkMergeState();
        source.sendSuccess(() -> Component.literal((formed ? "Built an Infinity gate at " : "Placed an Infinity gate's blocks at ")
                + pos.toShortString() + ", facing " + facing.getName() + " (" + blocks.size() + " ring and chevron blocks)"
                + (formed ? "" : ", but it didn't form")), true);
        return formed ? 1 : 0;
    }
}
