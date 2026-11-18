package io.github.stargatecommand.sginfinity;

import gcewing.sg.BaseMod.ModelSpec;
import gcewing.sg.SGCraft;
import gcewing.sg.block.SGBaseBlock;
import net.minecraft.block.properties.PropertyBool;
import net.minecraft.block.state.IBlockState;
import net.minecraft.tileentity.TileEntity;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.IBlockAccess;
import net.minecraft.world.World;

/**
 * SGCraft's stargate base, making Infinity gates. It merges with SGCraft's own Ring and Chevron
 * Blocks exactly as SGCraft's base does.
 */
public class InfinityBaseBlock extends SGBaseBlock {

    /**
     * Whether the gate has formed. SGCraft hides its own base then through its own block renderer;
     * this one is drawn from a block model, which is empty while merged (see the blockstate).
     */
    public static final PropertyBool MERGED = PropertyBool.create("merged");

    public InfinityBaseBlock() {
        super();
        // SGCraft gives its own blocks this as it registers them; the base's shape (its model's
        // bounds) is looked up through it
        mod = SGCraft.mod;
    }

    // called from the Block constructor, so MERGED must be static
    @Override
    protected void defineProperties() {
        super.defineProperties();
        addProperty(MERGED);
    }

    /**
     * No SGCraft model: SGCraft's renderer draws any of its blocks that has one, from SGCraft's own
     * base textures and even while merged. Without one, Minecraft draws this block from its block
     * model (the Infinity textures, nothing while merged), and it is a full block like SGCraft's.
     */
    @Override
    public ModelSpec getModelSpec(IBlockState state) {
        return null;
    }

    @Override
    public IBlockState getActualState(IBlockState state, IBlockAccess world, BlockPos pos) {
        return super.getActualState(state, world, pos).withProperty(MERGED, isMerged(world, pos));
    }

    @Override
    public TileEntity createNewTileEntity(World world, int meta) {
        return new InfinityBaseTE();
    }
}
