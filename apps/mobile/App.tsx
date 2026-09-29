import React from 'react';
import { StyleSheet, Text, View, SafeAreaView } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { APP_CONFIG, EXERCISE_KEYS } from '@fit-odyssey/config';
import { SquatAnalyzer } from '@fit-odyssey/pose-engine';

export default function App() {
  const squatAnalyzer = React.useMemo(() => new SquatAnalyzer(), []);

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar style="light" />
      <View style={styles.card}>
        <View style={styles.badge}>
          <Text style={styles.badgeText}>ODISHA HERITAGE</Text>
        </View>
        <Text style={styles.title}>{APP_CONFIG.NAME}</Text>
        <Text style={styles.tagline}>{APP_CONFIG.TAGLINE}</Text>

        <View style={styles.statsContainer}>
          <View style={styles.statBox}>
            <Text style={styles.statLabel}>Core Engine</Text>
            <Text style={styles.statValue}>{squatAnalyzer.name}</Text>
          </View>
          <View style={styles.statBox}>
            <Text style={styles.statLabel}>Exercises</Text>
            <Text style={styles.statValue}>
              {EXERCISE_KEYS.SQUAT} | {EXERCISE_KEYS.PUSHUP} | {EXERCISE_KEYS.PLANK}
            </Text>
          </View>
        </View>

        <Text style={styles.footer}>Phase 1: Monorepo Foundation Active</Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0d14',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
  },
  card: {
    width: '100%',
    maxWidth: 400,
    backgroundColor: '#121824',
    borderRadius: 20,
    padding: 24,
    borderWidth: 1,
    borderColor: '#1f293d',
    alignItems: 'center',
  },
  badge: {
    backgroundColor: 'rgba(245, 158, 11, 0.15)',
    borderColor: 'rgba(245, 158, 11, 0.3)',
    borderWidth: 1,
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 20,
    marginBottom: 12,
  },
  badgeText: {
    color: '#f59e0b',
    fontSize: 10,
    fontWeight: '700',
    letterSpacing: 1,
  },
  title: {
    fontSize: 28,
    fontWeight: '800',
    color: '#f8fafc',
    marginBottom: 8,
  },
  tagline: {
    fontSize: 13,
    color: '#94a3b8',
    textAlign: 'center',
    lineHeight: 18,
    marginBottom: 24,
  },
  statsContainer: {
    width: '100%',
    gap: 12,
    marginBottom: 20,
  },
  statBox: {
    backgroundColor: '#0f172a',
    borderRadius: 12,
    padding: 14,
    borderWidth: 1,
    borderColor: '#1e293b',
  },
  statLabel: {
    fontSize: 11,
    color: '#64748b',
    textTransform: 'uppercase',
    fontWeight: '600',
    marginBottom: 4,
  },
  statValue: {
    fontSize: 14,
    color: '#e2e8f0',
    fontWeight: '600',
  },
  footer: {
    fontSize: 11,
    color: '#475569',
    marginTop: 8,
  },
});
