package com.example.linux_container

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Foreground service que mantiene vivo el proceso de la app (y por tanto los
 * procesos hijos llama-server y agent-server, lanzados vía flutter_pty)
 * mientras la app esta en segundo plano. Muestra una notificacion persistente.
 *
 * No ejecuta nada por si mismo: su unica funcion es impedir que Android mate
 * el proceso. Se arranca/para desde Dart via MethodChannel.
 */
class AgentForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "xtr_agent_service"
        const val NOTIF_ID = 4711
        const val ACTION_START = "com.example.linux_container.AGENT_FGS_START"
        const val ACTION_STOP = "com.example.linux_container.AGENT_FGS_STOP"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }
        startAsForeground()
        return START_STICKY
    }

    private fun startAsForeground() {
        createChannel()
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this, 0, launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notif: Notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Agente activo")
            .setContentText("llama-server + agent-server en ejecucion")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setContentIntent(pi)
            .build()

        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIF_ID, notif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIF_ID, notif)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID, "Agente",
                    NotificationManager.IMPORTANCE_LOW
                )
                ch.description = "Mantiene activos los servicios del agente"
                ch.setShowBadge(false)
                mgr.createNotificationChannel(ch)
            }
        }
    }
}
