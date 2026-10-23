import React from 'react';
import {
    Modal,
    Paper,
    Box,
    Typography,
    Chip,
    IconButton,
    CircularProgress,
    Button
} from '@mui/material';

import CloseIcon from '@mui/icons-material/Close';
import CatchingPokemonIcon from '@mui/icons-material/CatchingPokemon';

const TYPE_COLORS = {
    grass: '#78C850',
    poison: '#A040A0',
    fire: '#F08030',
    water: '#6890F0',
    bug: '#A8B820',
    normal: '#A8A878',
    electric: '#F8D030',
    ground: '#E0C068',
    fairy: '#EE99AC',
    fighting: '#C02038',
    psychic: '#F85888',
    rock: '#B8A038',
    ghost: '#705898',
    ice: '#98D8D8',
    dragon: '#7038F8',
    flying: '#A890F0',
    steel: '#B8B8D0',
    dark: '#705848'
};

function InfoRow({ label, children, height = 70 }) {
    return (
        <Box
            sx={{
                bgcolor: '#fff',
                borderRadius: 2,
                overflow: 'hidden',
                display: 'flex',
                height: height
            }}
        >
            <Box
                sx={{
                    width: 140,
                    bgcolor: '#ececec',
                    display: 'flex',
                    justifyContent: 'center',
                    alignItems: 'center'
                }}
            >
                <Typography sx={{ fontSize: 18, fontWeight: 600 }}>
                    {label}
                </Typography>
            </Box>

            <Box
                sx={{
                    flex: 1,
                    display: 'flex',
                    justifyContent: 'center',
                    alignItems: 'center'
                }}
            >
                {children}
            </Box>
        </Box>
    );
}

function MoveCard({ move, type }) {
    return (
        <Box
            sx={{
                bgcolor: '#fff',
                borderRadius: '999px',
                px: 3,
                py: 1.5,
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center'
            }}
        >
            <Typography sx={{ fontSize: 17, fontWeight: 500 }}>
                {move}
            </Typography>

            <Chip
                label={type.toUpperCase()}
                sx={{
                    bgcolor: TYPE_COLORS[type?.toLowerCase()] || '#757575',
                    color: '#fff',
                    fontWeight: 'bold'
                }}
            />
        </Box>
    );
}

export default function PokemonDetailModal({
    open,
    onClose,
    pokemon,
    stats,
    team = [],
    onAddToTeam
}) {
    if (!pokemon) return null;

    const primaryType = stats?.types?.[0]?.toLowerCase() || 'normal';
    const isAlreadyInTeam = team.some(p => p.id === pokemon.id);

    return (
        <Modal open={open} onClose={onClose}>
            <Paper
                sx={{
                    position: 'absolute',
                    top: '50%',
                    left: '50%',
                    transform: 'translate(-50%, -50%)',
                    width: 1000,
                    height: 650,
                    overflow: 'hidden',
                    borderRadius: 0,
                    p: 0
                }}
            >
                {/* HEADER */}
                <Box
                    sx={{
                        height: 80,
                        bgcolor: '#000',
                        color: '#fff',
                        display: 'flex',
                        alignItems: 'center',
                        px: 4,
                        position: 'relative'
                    }}
                >
                    <Typography sx={{ fontSize: 30, fontWeight: 300 }}>
                        No. {String(pokemon.id).padStart(3, '0')}
                    </Typography>

                    <Typography
                        sx={{
                            ml: 8,
                            fontSize: 48,
                            fontWeight: 400,
                            textTransform: 'capitalize'
                        }}
                    >
                        {pokemon.name}
                    </Typography>

                    <Box
                        sx={{
                            position: 'absolute',
                            right: 20,
                            display: 'flex',
                            alignItems: 'center',
                            gap: 1
                        }}
                    >
                        <Button
                            variant="contained"
                            color={isAlreadyInTeam ? "inherit" : "success"}
                            disabled={isAlreadyInTeam}
                            startIcon={<CatchingPokemonIcon />}
                            onClick={(e) => onAddToTeam(e, pokemon)}
                            sx={{
                                textTransform: 'none',
                                fontWeight: 'bold',
                                borderRadius: 4,
                                height: 40,
                                px: 2,
                                "&.Mui-disabled": {
                                    bgcolor: "rgba(255, 255, 255, 0.12)",
                                    color: "rgba(255, 255, 255, 0.3)"
                                }
                            }}
                        >
                            {isAlreadyInTeam ? "In Squad" : "Add to Squad"}
                        </Button>

                        <IconButton onClick={onClose} sx={{ color: '#fff' }}>
                            <CloseIcon />
                        </IconButton>
                    </Box>
                </Box>

                {/* BODY */}
                <Box
                    sx={{
                        display: 'flex',
                        height: 'calc(100% - 80px)',
                        position: 'relative'
                    }}
                >
                    {/* RED DIAGONAL STRIPE */}
                    <Box
                        sx={{
                            position: 'absolute',
                            left: '48%',
                            width: 140,
                            height: '100%',
                            bgcolor: '#c72038',
                            transform: 'skewX(-15deg)',
                            zIndex: 1
                        }}
                    />

                    {/* LEFT SIDE */}
                    <Box
                        sx={{
                            flex: 1,
                            bgcolor: '#f5f5f5',
                            display: 'flex',
                            flexDirection: 'column',
                            justifyContent: 'center',
                            alignItems: 'center',
                            p: 4,
                            zIndex: 2,
                  '@keyframes windFloat': {
'0%': {
                transform: 'translateY(0px)',
            },
            '50%': {
                transform: 'translateY(-12px)',
            },
            '100%': {
                transform: 'translateY(0px)',
            }
}
                        }}
                    >
                        <Box
                            component="img"
                            src={pokemon.sprite}
                            alt={pokemon.name}
                            sx={{
                                width: 340,
                                height: 340,
                                objectFit: 'contain',
                                animation: 'windFloat 4s ease-in-out infinite',
                                transformOrigin: 'bottom center'
                            }}
                        />

                        <Box 
                            sx={{ 
                                mt: 2, 
                                px: 3, 
                                py: 2, 
                                bgcolor: 'rgba(0, 0, 0, 0.04)', 
                                borderRadius: 3,
                                width: '80%',
                                minHeight: 70,
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center'
                            }}
                        >
                            {!stats ? (
                                <CircularProgress size={24} color="error" />
                            ) : (
                                <Typography 
                                    variant="body1" 
                                    sx={{ 
                                        fontStyle: 'italic', 
                                        color: '#424242', 
                                        textAlign: 'center',
                                        lineHeight: 1.4,
                                        fontWeight: 400
                                    }}
                                >
                                    "{stats.description}"
                                </Typography>
                            )}
                        </Box>
                    </Box>

                    <Box
                        sx={{
                            width: 430,
                            bgcolor: '#df2f45',
                            p: 4,
                            display: 'flex',
                            flexDirection: 'column',
                            gap: 2,
                            zIndex: 2,
                            overflowY: 'auto'
                        }}
                    >
                        {!stats ? (
                            <Box
                                sx={{
                                    flex: 1,
                                    display: 'flex',
                                    justifyContent: 'center',
                                    alignItems: 'center',
                                    minHeight: 300
                                }}
                            >
                                <CircularProgress sx={{ color: '#fff' }} />
                            </Box>
                        ) : (
                            <>
                                <InfoRow label="Type" height={90}>
                                    <Chip
                                        label={primaryType.toUpperCase()}
                                        sx={{
                                            bgcolor: TYPE_COLORS[primaryType] || '#757575',
                                            color: '#fff',
                                            fontWeight: 'bold',
                                            fontSize: 14,
                                            px: 1,
                                            borderRadius: '8px'
                                        }}
                                    />
                                </InfoRow>

                                <InfoRow label="Ability">
                                    <Typography sx={{ fontSize: 18, fontWeight: 500 }}>
                                        {stats?.ability || 'Unknown'}
                                    </Typography>
                                </InfoRow>

                                <InfoRow label="Height">
                                    <Typography sx={{ fontSize: 18, fontWeight: 500 }}>
                                        {stats?.height ? `${stats.height} m` : '--'}
                                    </Typography>
                                </InfoRow>

                                <InfoRow label="Weight">
                                    <Typography sx={{ fontSize: 18, fontWeight: 500 }}>
                                        {stats?.weight ? `${stats.weight} kg` : '--'}
                                    </Typography>
                                </InfoRow>

                                <Typography
                                    sx={{
                                        color: '#fff',
                                        fontSize: 24,
                                        fontWeight: 700,
                                        mt: 2,
                                        mb: 1
                                    }}
                                >
                                    Moves
                                </Typography>

                                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                                    {stats?.moves?.map((move) => (
                                        <MoveCard
                                            key={move.name}
                                            move={move.name}
                                            type={move.type}
                                        />
                                    ))}
                                </Box>
                            </>
                        )}
                    </Box>
                </Box>
            </Paper>
        </Modal>
    );
}