
import React, { useState, useEffect } from 'react';
import { 
  Container, Grid, Card, CardContent, CardMedia, Typography, 
  TextField, Box, Alert, Snackbar, Paper, Divider,
  CircularProgress, IconButton, TablePagination, Modal, Avatar, Badge, Button
} from '@mui/material';
import CatchingPokemonIcon from '@mui/icons-material/CatchingPokemon';
import AddIcon from '@mui/icons-material/Add';
import CancelIcon from '@mui/icons-material/Cancel';
import LogoutIcon from '@mui/icons-material/Logout';
import LoginIcon from '@mui/icons-material/Login';
import PokemonDetailModal from './components/PokemonDetailModal';
import AuthPage from './components/AuthPage';
import { API_BASE_URL } from './config';

function App() {
  const [token, setToken] = useState(localStorage.getItem('token') || null);
  const [user, setUser] = useState(localStorage.getItem('username') || null);

  const [allPokemon, setAllPokemon] = useState([]);
  const [team, setTeam] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(12);

  const [openModal, setOpenModal] = useState(false);
  const [openAuthModal, setOpenAuthModal] = useState(false); // Auth popup flag
  const [selectedPokemon, setSelectedPokemon] = useState(null);
  const [selectedStats, setSelectedStats] = useState(null);
  
  const [alertMessage, setAlertMessage] = useState('');
  const [showAlert, setShowAlert] = useState(false);
  const [loading, setLoading] = useState(true);

  const [isSyncingLogin, setIsSyncingLogin] = useState(false);

  useEffect(() => {
    fetch(`${API_BASE_URL}/api/pokemon`)
      .then(res => res.json())
      .then(data => {
        setAllPokemon(data);
        setLoading(false);
      })
      .catch(err => {
        console.error(err);
        setLoading(false);
      });
  }, []);

useEffect(() => {
  if (isSyncingLogin) return;

  if (token) {
    fetch(`${API_BASE_URL}/api/squad`, {
      headers: { 'Authorization': `Bearer ${token}` }
    })
    .then(res => res.ok ? res.json() : [])
    .then(dbSquad => setTeam(dbSquad))
    .catch(() => {
      // 🌟 FIX: If the user is logged in, do NOT fall back to guest_team. Keep it empty or log an error.
      console.error("Cloud sync failed. Protecting session state.");
      setTeam([]); 
    });
  } else {
    const localTeam = JSON.parse(localStorage.getItem('guest_team')) || [];
    setTeam(localTeam);
  }
}, [token, isSyncingLogin]);

  const saveTeamState = async (updatedTeam) => {
    setTeam(updatedTeam);
    if (token) {
      try {
        await fetch(`${API_BASE_URL}/api/squad/sync`, {
          method: 'POST',
          headers: { 
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          },
          body: JSON.stringify(updatedTeam)
        });
      } catch (err) {
        console.error("Failed pushing team update to db sync matrix profile:", err);
      }
    } else {
      localStorage.setItem('guest_team', JSON.stringify(updatedTeam));
    }
  };

const handleLoginSuccess = async (userToken, username) => {
  setIsSyncingLogin(true);

  setToken(userToken);
  setUser(username);
  localStorage.setItem('token', userToken);
  localStorage.setItem('username', username);
  setOpenAuthModal(false);

  localStorage.removeItem('guest_team');

  try {
    const res = await fetch(`${API_BASE_URL}/api/squad`, {
      headers: { 'Authorization': `Bearer ${userToken}` }
    });
    
    if (res.ok) {
      const dbSquad = await res.json();
      setTeam(dbSquad); 
    } else {
      setTeam([]);
    }
  } catch (err) {
    console.error("Failed fetching authenticated cloud squad:", err);
    setTeam([]);
  } finally {
    setIsSyncingLogin(false);
  }
};

  const handleLogout = () => {
    setToken(null);
    setUser(null);
    localStorage.removeItem('token');
    localStorage.removeItem('username');
    setTeam([]); 
  };

  const handleOpenDetails = async (pokemon) => {
    setSelectedPokemon(pokemon);
    setSelectedStats(null); 
    setOpenModal(true);
    try {
      const res = await fetch(`${API_BASE_URL}/api/pokemon/stats/${pokemon.id}`);
      const data = await res.json();
      setSelectedStats(data);
    } catch (err) {}
  };

  const handleAddToTeam = (e, pokemon) => {
    e.stopPropagation();
    if (team.length >= 5) {
      setAlertMessage("Your team is full! You cannot have more than 5 Pokémon.");
      setShowAlert(true);
      return;
    }
    if (team.some(p => p.id === pokemon.id)) {
      setAlertMessage(`${pokemon.name} is already in your team!`);
      setShowAlert(true);
      return;
    }
    saveTeamState([...team, pokemon]);
  };

  const handleRemoveFromTeam = (pokemonId) => {
    saveTeamState(team.filter(p => p.id !== pokemonId));
  };

  const filteredPokemon = allPokemon.filter(pokemon => 
    pokemon.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const paginatedPokemon = filteredPokemon.slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage);

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="100vh">
        <CircularProgress color="error" size={60} />
      </Box>
    );
  }

  return (
    <Container maxWidth="lg" sx={{ mt: 3, mb: 4 }}>
      
      <Box display="flex" justifyContent="space-between" alignItems="center" flexWrap="wrap" sx={{ mb: 3, gap: 2 }}>
        <Box display="flex" alignItems="center" gap={3}>
          <Typography variant="h4" sx={{ fontWeight: 'bold', color: '#ef5350', display: 'flex', alignItems: 'center' }}>
            <CatchingPokemonIcon sx={{ mr: 1, fontSize: 35 }} />
            PokéManager
          </Typography>
          <Typography variant="subtitle1" sx={{ color: 'text.secondary', fontStyle: 'italic' }}>
            {token ? <>Logged in as: <b>{user}</b> (Cloud Sync Active) </> : <>Guest Session (Local Mode)</>}
          </Typography>
        </Box>

        <Box display="flex" alignItems="center" gap={2}>
          <Paper elevation={2} sx={{ p: 1.5, px: 3, borderRadius: 20, display: 'flex', alignItems: 'center', gap: 2 }}>
            <Typography variant="subtitle2" sx={{ fontWeight: 'bold', color: 'text.secondary' }}>
              SQUAD ({team.length}/5):
            </Typography>
            {team.length === 0 ? (
              <Typography variant="body2" sx={{ color: 'text.disabled', fontStyle: 'italic' }}>Empty</Typography>
            ) : (
              <Box display="flex" gap={1.5}>
                {team.map(p => (
                  <Badge
                    key={`team-badge-${p.id}`}
                    overlap="circular"
                    anchorOrigin={{ vertical: 'top', horizontal: 'right' }}
                    badgeContent={
                      <IconButton size="small" onClick={() => handleRemoveFromTeam(p.id)} sx={{ p: 0, color: '#ef5350', bgcolor: 'white', '&:hover': { bgcolor: '#ffcdd2' } }}>
                        <CancelIcon fontSize="small" />
                      </IconButton>
                    }
                  >
                    <Avatar 
                      src={p.sprite} 
                      alt={p.name} 
                      onClick={() => handleOpenDetails(p)}
                      sx={{ width: 44, height: 44, bgcolor: '#f5f5f5', border: '2px solid #4caf50', cursor: 'pointer' }} 
                    />
                  </Badge>
                ))}
              </Box>
            )}
          </Paper>

          {token ? (
            <Button variant="outlined" color="error" startIcon={<LogoutIcon />} onClick={handleLogout} sx={{ borderRadius: 20 }}>
              Logout
            </Button>
          ) : (
            <Button variant="contained" color="primary" startIcon={<LoginIcon />} onClick={() => setOpenAuthModal(true)} sx={{ borderRadius: 20 }}>
              Login / Register
            </Button>
          )}
        </Box>
      </Box>

      <Divider sx={{ mb: 4 }} />

      <Paper elevation={1} sx={{ p: 2, mb: 4, borderRadius: 2 }}>
        <Grid container spacing={2} alignItems="center" justifyContent="space-between">
          <Grid item xs={12} sm={6}>
            <TextField 
              fullWidth 
              size="small"
              label="Search Pokémon..." 
              variant="outlined" 
              value={searchTerm}
              onChange={(e) => { setSearchTerm(e.target.value); setPage(0); }}
            />
          </Grid>
          <Grid item xs={12} sm={6} display="flex" justifyContent="flex-end">
            <TablePagination
              component="div"
              count={filteredPokemon.length}
              page={page}
              onPageChange={(e, p) => setPage(p)}
              rowsPerPage={rowsPerPage}
              onRowsPerPageChange={(e) => { setRowsPerPage(parseInt(e.target.value, 10)); setPage(0); }}
              rowsPerPageOptions={[6, 12, 24]}
            />
          </Grid>
        </Grid>
      </Paper>

      <Grid container spacing={3}>
        {paginatedPokemon.map(pokemon => {
          const isAlreadyInTeam = team.some(p => p.id === pokemon.id);
          return (
            <Grid item xs={6} sm={4} md={3} lg={2} key={pokemon.id}>
              <Card onClick={() => handleOpenDetails(pokemon)} sx={{ position: 'relative', cursor: 'pointer', borderRadius: 3, '&:hover': { boxShadow: 4 } }}>
                <IconButton 
                  disabled={isAlreadyInTeam}
                  onClick={(e) => handleAddToTeam(e, pokemon)}
                  sx={{ position: 'absolute', top: 5, right: 5, zIndex: 2 }}
                >
                  <AddIcon color={isAlreadyInTeam ? "disabled" : "success"} />
                </IconButton>
                <CardMedia component="img" height="110" image={pokemon.sprite} alt={pokemon.name} sx={{ pt: 2, objectFit: 'contain' }} />
                <CardContent sx={{ textAlign: 'center', p: '12px !important' }}>
                  <Typography variant="body2" color="text.secondary" sx={{ fontSize: 11, fontWeight: 'bold' }}>#{String(pokemon.id).padStart(3, '0')}</Typography>
                  <Typography variant="body1" sx={{ fontWeight: '600', textTransform: 'capitalize', fontSize: 14 }}>{pokemon.name}</Typography>
                </CardContent>
              </Card>
            </Grid>
          );
        })}
      </Grid>

      <PokemonDetailModal open={openModal} onClose={() => setOpenModal(false)} pokemon={selectedPokemon} stats={selectedStats} team={team} onAddToTeam={handleAddToTeam} />

      <Modal open={openAuthModal} onClose={() => setOpenAuthModal(false)} sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
         <Box sx={{ outline: 'none' }}>
            <AuthPage onLoginSuccess={handleLoginSuccess} />
         </Box>
      </Modal>

      <Snackbar open={showAlert} autoHideDuration={3500} onClose={() => setShowAlert(false)}>
        <Alert onClose={() => setShowAlert(false)} severity="warning" variant="filled">{alertMessage}</Alert>
      </Snackbar>
    </Container>
  );
}

export default App;
